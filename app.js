const mongoose = require("./db/mongooseDb");
const express = require("express");
const app = express();
const https = require("https");
const fs = require("fs");
// const path = require('path');
const cheerio = require("cheerio");
const nodemailer = require("nodemailer");
const schedule = require("node-schedule");
const targetUrl = "https://m.cnal.com/market/changjiang/";
//
const puppeteer = require("puppeteer");
// 创建一个SMTP客户端配置  ytkwuiybbzmcbgei
const config = {
    host: "smtp.qq.com", //网易163邮箱 smtp.163.com
    port: 465, //网易邮箱端口 25
    auth: {
        user: "339266478@qq.com", //邮箱账号
        pass: "puwfvikmzlrlbjdf" //邮箱的授权码
    }
};
// 创建一个SMTP客户端对象
const transporter = nodemailer.createTransport(config);
// 创建一个邮件对象
const mail = {
    // 发件人
    from: "<339266478@qq.com>",
    // 主题
    subject: "铜铝价格",
    // 收件人
    to: '328826649@qq.com',
    cc: "339266478@qq.com",
    // 邮件内容，HTML格式
    html: ""
};
const listData = [
    {
        id: 1,
        size: "0.08",
        addMuch: 45,
        plating: 0,
    },
    {
        id: 2,
        size: "0.09",
        addMuch: 40,
        plating: 0,
    },
    {
        id: 3,
        size: "0.10",
        addMuch: 25.5,
        plating: 0,
    },
    {
        id: 4,
        size: "0.11",
        addMuch: 24.5,
        plating: 0,
    },
    {
        id: 5,
        size: "0.12",
        addMuch: 21.0,
        plating: 0,
    },
    {
        id: 4,
        size: "0.13",
        addMuch: 20.0,
        plating: 0,
    },
    {
        id: 5,
        size: "0.14-0.15",
        addMuch: 16.0,
        plating: 0,
    },
    {
        id: 6,
        size: "0.16-0.17",
        addMuch: 15.0,
        plating: 0,
    },
    {
        id: 7,
        size: "0.18-0.19",
        addMuch: 14.5,
        plating: 21.00,
    },
    {
        id: 8,
        size: "0.20-0.24",
        addMuch: 13.5,
        plating: 19.00,
    },
    {
        id: 9,
        size: "0.25-0.29",
        addMuch: 13.0,
        plating: 18.00,
    },
    {
        id: 10,
        size: "0.30-0.39",
        addMuch: 12.5,
        plating: 17.50,
    },
    {
        id: 11,
        size: "0.40-1.3",
        addMuch: 12.0,
        plating: 17.00,
    }
];

const dataParams = {
    type: {
        type: Number
    },
    price: {
        type: Number
    },
    upDateTime: {
        type: String
    },
    creatDate: {
        type: Number
    }
};
// 铜
const PriceCopperdb = mongoose.model("coppers", dataParams);
// 铝
const PriceAluminumsdb = mongoose.model("aluminums", dataParams);

// 定时器
const Rule2 = new schedule.RecurrenceRule();
Rule2.hour = [9, 10, 11];
Rule2.minute = [00, 15];
let repTime = 0
let nowCoPrice = 0
let nowAlPrice = 0

schedule.scheduleJob(Rule2, () => {
    getPage()
});

function getPage () { 
    (async (nowCoPrice, nowAlPrice) => {
        const browser = await puppeteer.launch({
            headless: 'new',
            dumpio: false,
            ignoreHTTPSErrors: true,
            defaultViewport: {
                width: 1280,
                height: 960
            },
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--enable-gpu',
                '--headless',
                '--disable-gpu',
                '--unlimited-storage',
                '--disable-dev-shm-usage',
                '--full-memory-crash-report',
                '--disable-extensions',
                '--mute-audio',
                '--no-zygote',
                '--no-first-run',
                '--start-maximized'
            ]
        });

        const page = await browser.newPage();
        console.log('打开网址----------')
            //
        await page.goto(targetUrl, { timeout: 60000 });
        console.log('打开网址----------001')
        await page.screenshot({
            path: "./public/images/example.jpg",
            clip: {
                x: 0,
                y: 0,
                width: 800,
                height: 500
            }
        });
        console.log('打开网址----------002截图后')
        await browser.close();
        console.log('打开网址----------003浏览器关闭')
        https
            .get(targetUrl, res => {
                var html = ""; // 保存抓取到的 HTML 源码

                res.setEncoding("utf-8");

                // 抓取页面内容
                res.on("data", chunk => {
                    html += chunk;
                });

                res.on("end", () => {
                    let $ = cheerio.load(html),
                        priceData = {
                            creatDate: new Date().getTime()
                        },
                        copper = {},
                        aluminum = {};

                    for (
                        let i = 0, len = $(".cnal-market-table td").length;
                        i < len;
                        i++
                    ) {
                        let type = $($(".cnal-market-table td")[i]).text(),
                            $parent = $($(".cnal-market-table td")[i]).parent();

                        if (type === "铝") {
                            aluminum.price = ($($parent.find("td")[2]).text() * 1) / 1000;
                            aluminum.type = 0;
                        } else if (type === "铜") {
                            copper.price = ($($parent.find("td")[2]).text() * 1) / 1000;
                            copper.type = 1;
                        }
                        console.log('type----', type)
                        priceData.upDateTime = $($parent.find("td")[4]).text();
                    }

                    let { price: coPrice } = copper;
                    let { price: alPrice } = aluminum;
                    console.log(coPrice, alPrice)
                    if (!coPrice) { 
                        console.log('报错----')
                        if (repTime < 6) {
                            repTime++
                            getPage()
                        } else { 
                            repTime = 0
                            new Error('获取不到价格')
                        }
                        return
                    }


                    let shtml = `<p style="font-size:20px;font-weight:bold;padding:0px;margin:0px;">当前
                                <span style="color:blue;">铝</span>价格：
                                <span style="color:red;">${alPrice}</span></p> 
                                <p style="font-size:20px;font-weight:bold;padding:0px;margin:0px;"> 当前
                                <span style="color:green;">铜</span>价格： 
                                <span style="color:red;">${coPrice}</span></p> 
                                <p>截图如下:</p>
                                <table class="table" style="border: 1px solid #999999;">
                                    <tr>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">序号</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">规格</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">加工费<br/>CCAQA-1/155</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">当日铜价</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">当日铝价</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">当日含税价单价</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">当日不含税单价</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">电镀加工费</td>
                                    <td style="padding: 6px 3px;text-align: center;
                                    border: 1px solid #999999;">电镀含税价格</td>
                                </tr>`;

                    for (let e = 0, elen = listData.length; e < elen; e++) {
                        let item = listData[e],
                            colHtml = `<td rowspan="13" style="background: #a1d8fc;">${coPrice}</td>
                        <td rowspan="13" style="background: #c5a1fc;">${alPrice}</td>`;
                        let { size, addMuch, plating } = item;

                        shtml += `<tr class="item">
                                <td style="	padding: 6px 3px;text-align: center;border: 1px solid #999999;">${e+1}</td>
                                <td style="white-space: nowrap;	padding: 6px 3px;text-align: center;border: 1px solid #999999;">${size}</td>
                                <td style="	padding: 6px 3px;text-align: center;border: 1px solid #999999;">${addMuch}</td>
                                ${e === 0 ? colHtml : ""}
                                <td style="	padding: 6px 3px;text-align: center;border: 1px solid #999999;">${(
                                coPrice * 0.3 +
                                alPrice * 0.7 +
                                item.addMuch
                            ).toFixed(2)}</td>
                                <td style="	padding: 6px 3px;text-align: center;\
                                border: 1 px solid #999999;">${(
                                (coPrice * 0.3 +
                                    alPrice * 0.7 +
                                    item.addMuch) /
                                1.08
                            ).toFixed(2)}</td>
                                <td style="padding: 6px 3px;text-align: center;border: 1px solid #999999;">${plating}</td>
                                <td style=" padding: 6px 3px;text-align: center;\
                                border: 1 px solid #999999;">${alPrice+plating}</td>
                            </tr>`;
                    }
                    shtml += '</table><p style="float: left"><img src="cid:img1"></p>';

                    mail.html = shtml;
                    mail.subject = priceData.upDateTime + "铜铝价格";
                    // 伪代码
                    let img = fs.readFileSync("./public/images/example.jpg");

                    mail.attachments = [
                        {
                            filename: "实时价格网站截图",
                            content: img,
                            cid: "img1"
                        }
                    ];

                    // 铜价格保存
                    PriceCopperdb.findOne(
                        {
                            upDateTime: priceData.upDateTime
                        },
                        (err, doc) => {
                            if (doc === null) {
                                let coPriceDb = new PriceCopperdb(
                                            Object.assign(copper, priceData)
                                        );
                                coPriceDb.save();
                            }
                        }
                    );

                    // 铝价格保存
                    PriceAluminumsdb.findOne(
                        {
                            upDateTime: priceData.upDateTime
                        },
                        (err, doc) => {
                            if (doc === null) {
                                let alPriceDb = new PriceAluminumsdb(
                                            Object.assign(aluminum, priceData)
                                        );
                                alPriceDb.save();
                            }
                            
                            if (nowCoPrice === coPrice && nowAlPrice === alPrice) {
                                console.log('价格相同')
                                return
                            }
                            send(mail);
                            nowCoPrice = coPrice
                            nowAlPrice = alPrice
                            // setTimeout(() => {
                            //     fs.unlinkSync("./public/images/example.jpg");
                            // },2000);
                        }
                    );
                });
            })
            .on("error", function (err) {
                console.log('加载失败---',err);
            });
    })(nowCoPrice, nowAlPrice);
}

// 发送邮件
function send(mail) {
    transporter.sendMail(mail, function (error, info) {
        if (error) {
            return console.log(error);
        }
        console.log('mail sent:', info.response);
    });
}

app.use('/public', express.static('public'));
app.get('/', (req, res) => {
    res.sendFile(__dirname + "/" + "index.html");
});
app.get('/getPrice', (req, res) => {

    PriceModeldb.find({
        // creatDate: {
        //     $lt: req.query.time
        // }
    }, function (err, doc) {
        res.end(JSON.stringify(doc[0]));
    }).sort({_id: -1}).limit(1);
});

app.get('/getPriceAll', (req, res) => {

    const params = req.query;
    const query = PriceModeldb.find({});

    let num = params.pageSize*1 || 10;        // 每页几条
    let total = 0;                            // 总数
    let skip = (params.pageNo*1-1) * num;     // 页数*条数
    let lastPageNum = 0;

    PriceModeldb.find({
        // creatDate: {
        //     $lt: req.query.time
        // }
    },
    function (err, data) {
        if (err) {
            //查询错误
        } else {
            total = data.length; //获得总条数
            lastPageNum = Math.ceil(total/num);
        }
    });

    query.limit(num); //限制条数，每次查多少条
    query.skip(skip); //开始数 ，当前查第几页*每页显示第几条得到开始条数
    query.exec((err, value) => {

        if (err) {
            //返回错误
        } else {
            //得到数据
            const page = {
                page_no: (params.pageNo*1) + 1,
                page_size: num,
                total: total,
                lastPageNum: lastPageNum,
                data: [...value]
            };
            console.log('回调成功')
            //返回成功
            res.end(JSON.stringify(page));
        }

    });

});

var server = app.listen(3000, () =>{

    var host = server.address().address;
    var port = server.address().port;

    console.log("应用实例，访问地址为 http://%s:%s", host, port)

});

// 截取网页生成图
// #依赖库
// yum install pango.x86_64 libXcomposite.x86_64 libXcursor.x86_64 libXdamage.x86_64 libXext.x86_64 libXi.x86_64 libXtst.x86_64 cups-libs.x86_64 libXScrnSaver.x86_64 libXrandr.x86_64 GConf2.x86_64 alsa-lib.x86_64 atk.x86_64 gtk3.x86_64 -y
// #字体
// yum install ipa-gothic-fonts xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-utils xorg-x11-fonts-cyrillic xorg-x11-fonts-Type1 xorg-x11-fonts-misc -y
