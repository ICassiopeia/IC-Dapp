var fs = require('fs');
const path = require("path");
const Papa = require("papaparse");

// const fetcher = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
// const headers = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args).Headers);
// globalThis.fetch = fetcher;
// globalThis.Headers = headers;
// global.Headers = headers;

// import {Headers} from 'node-fetch';

const { getActor, getHost } = require('./config');

const ENV = process.env.ENV || "local"
const DEFAULT_HOST = getHost(ENV)

const main = async () => {
  const actor = getActor("data_assets", ENV, DEFAULT_HOST);

  var datasetConfig = {
    name: "Exams dataset from Kaggle",
    assetId: "kaggle_exams_dataset",
    dimensions: [],
  }
  const data = fs.readFileSync(path.join(__dirname, "exams.csv"), 'utf8');

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
        datasetConfig.dimensions.push({
          dimensionId : i,
          title: col,
          dimensionType: typeof results.data[0][col] === 'number' ?
            {Numerical: null} : {Categorical: [...new Set(results.data.map(row => row[col]).flat())]}
        })
      }
      // format values
      for(let i=0; i<results.data.length; i++) {
        const values = Object.entries(results.data[i]).map(([key, val]) => {
          return {
            dimensionId: dimKV[key],
            value: dimKVTypes[key]==='num' ? {metric: val} : {attribute: val},
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

main();