var fs = require('fs');
const path = require("path");
const Papa = require("papaparse");

const { getActor, getHost } = require('./config');

const ENV = process.env.ENV || "local"
const DEFAULT_HOST = getHost(ENV)

const MOCK_DATASETS = [
  {
    name: "Exams dataset from Kaggle",
    assetId: "kaggle_exams_dataset",
    target: "exams.csv",
  },
  {
    name: "Film dataset",
    assetId: "kaggle_film_dataset",
    target: "film.csv",
  },
  {
    name: "Cars dataset from Kaggle",
    assetId: "kaggle_cars_dataset",
    target: "cars.csv",
  }
]

const loadDataset = async (config) => {
  const actor = getActor("data_assets", ENV, DEFAULT_HOST);

  console.log("Loading dataset", config.target)

  var datasetConfig = {
    name: config.name,
    assetId: config.assetId,
    dimensions: [],
  }
  const data = fs.readFileSync(path.join(__dirname, config.target), 'utf8');

  // Processing CSV
  var datasetEntries=[];
  Papa.parse(data, {
    // download: true,
    dynamicTyping: true,
    header: true,
    complete: function(results) {
      // build dimensions
      var dimKV = {}
      var dimKVTypes = {}
      for(let i=0; i<results.meta.fields.length; i++) {
        const col = results.meta.fields[i]
        dimKV[col] = i
        dimKVTypes[col] = typeof results.data[0][col] === 'number' ? 'num' : 'cat'
        var dimensionType;
        if( typeof results.data[0][col] === 'number') dimensionType = {Numerical: null}
        else if(!results.data.find(row => row[col] === null) && [...new Set(results.data.map(row => row[col]).flat())].length < results.data.length/10) dimensionType = {Categorical: [...new Set(results.data.map(row => row[col]).flat())]}
        else dimensionType = {Freetext: null}
        datasetConfig.dimensions.push({
          dimensionId : i,
          title: col,
          dimensionType
        })
      }
      // format values
      for(let i=0; i<results.data.length; i++) {
        const values = Object.entries(results.data[i]).map(([key, val]) => {
          return {
            dimensionId: dimKV[key],
            value: dimKVTypes[key]==='num' ? {metric: parseInt(val*100)} : {attribute: val || "null"},
          }
        })
        datasetEntries.push({
          id: {id: i},
          values,
        })

      }
    }
  });
  
  console.log("Mint dataset")
  var datasetId, dataset
  try{
    const createDatasetRequest = {
      metadataNFT: JSON.stringify({name: datasetConfig.name, assetId: datasetConfig.assetId})
        .split('').map(x => x.charCodeAt()), // to convert to JSON string to blockchain "blob" data type
      category: ["demographics", "social"],
      datasetConfig,
    }
    // console.log("createDatasetRequest", createDatasetRequest)
    datasetId = await actor.createDataSet(createDatasetRequest);
    dataset = (await actor.getDatasetByDatasetId(datasetId))[0];
  } catch (e) {
    console.error(e);
  };
  console.log(`Dataset ${datasetId} configuration:`, dataset)
  // console.log("Sample:",datasetEntries[0])

  try{
    if(datasetId) {
      console.log(`Uploading ${datasetEntries.length} entries for dataset ${datasetId}`)
      const BATCH_SIZE = 100
      const chunks = datasetEntries.reduce((resultArray, item, index) => { 
        const chunkIndex = Math.floor(index/BATCH_SIZE)
        if(!resultArray[chunkIndex]) {
          resultArray[chunkIndex] = [] // start a new chunk
        }
        resultArray[chunkIndex].push(item)
        return resultArray
      }, [])
      for(i=0;i<chunks.length;i++) {
        console.log(`Uploading data chunk ${i+1}/${chunks.length}`)
        await actor.putManyEntries(datasetId, chunks[i])
      }
    }
  } catch (e) {
    console.error(e);
  };
};

const main = async () => {
  for(let i=0; i<MOCK_DATASETS.length; i++) await loadDataset(MOCK_DATASETS[i])
};

main();