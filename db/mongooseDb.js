const mongoose = require('mongoose');
var DB_URL = 'mongodb://price:Liuyuyi1989@127.0.0.1:27017/price';
mongoose.Promise = global.Promise;
/**
 * 连接
 */
mongoose.connect(DB_URL, {
    useNewUrlParser: true, 
    useUnifiedTopology: true
},function (err) {
    if(err){
        console.log('connection'+err)
    } else {
        console.log('connection success')
    }
});

/**
 * 连接成功
 */
mongoose.connection.on('connected', function () {
    // console.log('Mongoose connection success to ' + DB_URL);
});

/**
 * 连接异常
 */
mongoose.connection.on('error', function (err) {
    // console.log('Mongoose connection error: ' + err);
});

/**
 * 连接断开
 */
mongoose.connection.on('disconnected', function () {
    // console.log('Mongoose connection disconnected');
});

module.exports = mongoose
