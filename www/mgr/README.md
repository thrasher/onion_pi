# notes on creating this node.js app

# install node
brew install node

# install express and nodemon
npm install -g express-generator
npm install -g nodemon

# generate the application skeleton using express
express mgr --hogan -c less
cd mgr && npm install

# run the app
DEBUG=mgr ./bin/www

# run the app
nodemon bin/www

# configure bootstrap
npm install -g grunt-cli
