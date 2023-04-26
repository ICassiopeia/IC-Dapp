const path = require("path");
const webpack = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const CopyPlugin = require("copy-webpack-plugin");

const network = process.env.DFX_NETWORK || (process.env.NODE_ENV === "production" ? "ic" : "local");

const DFINITY_NETWORK = network === 'local' ? "http://localhost:8000" : "https://ic0.app"

function initCanisterEnv() {
  let localCanisters, prodCanisters;
  try {
    localCanisters = require(path.resolve(
      ".dfx",
      "local",
      "canister_ids.json"
    ));
  } catch (error) {
    console.log("No local canister_ids.json found. Continuing production");
  }
  try {
    prodCanisters = require(path.resolve("canister_ids.json"));
  } catch (error) {
    console.log("No production canister_ids.json found. Continuing with local");
  }

  const canisterConfig = network === "local" ? localCanisters : prodCanisters;

  return Object.entries(canisterConfig).reduce((prev, current) => {
    const [canisterName, canisterDetails] = current;
    prev[canisterName.toUpperCase() + "_CANISTER_ID"] =
      canisterDetails[network];
    return prev;
  }, {});
}
const canisterEnvVariables = initCanisterEnv();
console.log("canisterEnvVariables", canisterEnvVariables)

const isDevelopment = process.env.NODE_ENV !== "production";

const frontendDirectory = "dapp_frontend";
const frontend_entry = path.join("src", frontendDirectory, "public", "index.html");
const app_entry = path.join("src", frontendDirectory, "src", "index.tsx")

module.exports = {
  target: "web",
  mode: isDevelopment ? "development" : "production",
  entry: {
    index: path.resolve(__dirname, app_entry),
  },
  devtool: isDevelopment ? "source-map" : false,
  optimization: {
    minimize: !isDevelopment,
    minimizer: [new TerserPlugin()],
  },
  resolve: {
    extensions: [".js", ".ts", ".jsx", ".tsx"],
    fallback: {
      assert: require.resolve("assert/"),
      buffer: require.resolve("buffer/"),
      events: require.resolve("events/"),
      stream: require.resolve("stream-browserify/"),
      util: require.resolve("util/"),
    },
  },
  output: {
    filename: "index.js",
    path: path.join(__dirname, "dist", frontendDirectory),
    publicPath: '/',
  },

  module: {
    rules: [
      {
        test: /\.(css|scss)$/,
        include: [
          path.resolve(__dirname, "node_modules"),
          path.resolve(__dirname, "src", frontendDirectory, "src", "assets")
        ],
        use: [
          'style-loader',
          'css-loader',
          'sass-loader'
        ]
      },
      {
        test: /\.(png|svg|ipynb|jpg|webm)$/,
        use: [
          'file-loader',
        ],
      },
      {
        test: /\.(ts|tsx)/,
        include: path.resolve(__dirname, "src", frontendDirectory, "src"),
        exclude: [
          path.resolve(__dirname, "node_modules"),
          path.resolve(__dirname, "src", frontendDirectory, "src", "assets"),
        ],
        use: [
          {
            loader: 'babel-loader',
            options: {
              babelrc: true,
              cacheDirectory: true,
              "presets": [
                "@babel/preset-react",
                "@babel/preset-typescript",
                [
                  "@babel/preset-env",
                  {
                    "useBuiltIns": "usage",
                    "corejs": "3.26"
                  }
                ]
              ]
            },
          },
          {
            loader: 'ts-loader'
          }
        ]
      }
    ]
  },

  plugins: [
    new HtmlWebpackPlugin({
      template: path.join(__dirname, frontend_entry),
      cache: false,
    }),
    new webpack.EnvironmentPlugin({
      NODE_ENV: "development",
      DFINITY_NETWORK,
      DFX_NETWORK: "local",
      ...canisterEnvVariables,
    }),
    new webpack.ProvidePlugin({
      Buffer: [require.resolve("buffer/"), "Buffer"],
      process: require.resolve("process/browser"),
    }),
    new CopyPlugin({
      patterns: [
        {
          from: `src/${frontendDirectory}/src/.ic-assets.json*`,
          to: ".ic-assets.json5",
          noErrorOnMissing: true
        },
      ],
    }),
  ],
  // proxy /api to port 4943 during development.
  // if you edit dfx.json to define a project-specific local network, change the port to match.
  devServer: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4943",
        changeOrigin: true,
        pathRewrite: {
          "^/api": "/api",
        },
      },
    },
    static: path.resolve(__dirname, "src", frontendDirectory, "src", "assets"),
    hot: true,
    watchFiles: [path.resolve(__dirname, "src", frontendDirectory, "src")],
    liveReload: true,
    historyApiFallback: true,
  },
};
