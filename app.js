const express = require("express");
const app = express();
const https = require("https");
const fs = require("fs");
const cheerio = require("cheerio");
const nodemailer = require("nodemailer");
const schedule = require("node-schedule");
const mysql = require("mysql2/promise");
const targetUrl = "https://m.cnal.com/market/changjiang/";
const puppeteer = require("puppeteer");

// 创建一个SMTP客户端配置
try {
  var config = {
      host: "smtp.qq.com",
      port: 465,
      auth: {
          user: "339266478@qq.com",
          pass: "puwfvikmzlrlbjdf"
      }
  };
  var transporter = nodemailer.createTransport(config);
  var mail = {
      from: "<339266478@qq.com>",
      subject: "铜铝价格",
      to: '328826649@qq.com',
      cc: "339266478@qq.com",
      html: ""
  };
} catch (error) {
  console.error("邮件配置错误:", error);
  var transporter = null;
  var mail = null;
}

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

// MySQL 连接配置
const mysqlConfig = {
  host: 'localhost',
  user: 'root',
  password: 'Liuyuyi1989',
  database: 'price_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// 创建数据库连接池
const pool = mysql.createPool(mysqlConfig);

// 初始化数据库
async function initDatabase() {
  try {
    const connection = await pool.getConnection();
    
    // 创建数据库（如果不存在）
    await connection.query('CREATE DATABASE IF NOT EXISTS price_db');
    await connection.query('USE price_db');
    
    // 创建铜价格表
    await connection.query(`
      CREATE TABLE IF NOT EXISTS coppers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        type INT,
        price DOUBLE,
        upDateTime VARCHAR(50),
        creatDate BIGINT,
        UNIQUE KEY unique_updatetime (upDateTime)
      )
    `);
    
    // 创建铝价格表
    await connection.query(`
      CREATE TABLE IF NOT EXISTS aluminums (
        id INT AUTO_INCREMENT PRIMARY KEY,
        type INT,
        price DOUBLE,
        upDateTime VARCHAR(50),
        creatDate BIGINT,
        UNIQUE KEY unique_updatetime (upDateTime)
      )
    `);
    
    connection.release();
    console.log('数据库初始化成功');
  } catch (error) {
    console.error('数据库初始化失败:', error);
  }
}

// 定时器
const Rule2 = new schedule.RecurrenceRule();
Rule2.hour = [9, 10, 11];
Rule2.minute = [00, 15];
let repTime = 0;
let nowCoPrice = 0;
let nowAlPrice = 0;

// 初始化数据库
initDatabase();

// 定时任务
try {
  schedule.scheduleJob(Rule2, () => {
    getPage();
  });
} catch (error) {
  console.error('定时任务配置错误:', error);
}

function getPage() {
  (async (nowCoPrice, nowAlPrice) => {
    try {
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
      console.log('打开网址----------');
      await page.goto(targetUrl, { timeout: 60000 });
      console.log('打开网址----------001');
      
      // 确保目录存在
      if (!fs.existsSync('./public/images')) {
        fs.mkdirSync('./public/images', { recursive: true });
      }
      
      await page.screenshot({
          path: "./public/images/example.jpg",
          clip: {
              x: 0,
              y: 0,
              width: 800,
              height: 500
          }
      });
      console.log('打开网址----------002截图后');
      await browser.close();
      console.log('打开网址----------003浏览器关闭');
      
      https.get(targetUrl, res => {
          var html = "";

          res.setEncoding("utf-8");

          res.on("data", chunk => {
              html += chunk;
          });

          res.on("end", async () => {
              try {
                  let $ = cheerio.load(html),
                      priceData = {
                          creatDate: new Date().getTime()
                      },
                      copper = {},
                      aluminum = {};

                  for (
                      let i = 0, len = $("td").length; i < len; i++
                  ) {
                      let type = $($("td")[i]).text(),
                          $parent = $($("td")[i]).parent();

                      if (type === "铝") {
                          aluminum.price = ($($parent.find("td")[2]).text() * 1) / 1000;
                          aluminum.type = 0;
                      } else if (type === "铜") {
                          copper.price = ($($parent.find("td")[2]).text() * 1) / 1000;
                          copper.type = 1;
                      }
                      console.log('type----', type);
                      priceData.upDateTime = $($parent.find("td")[4]).text();
                  }

                  let { price: coPrice } = copper;
                  let { price: alPrice } = aluminum;
                  console.log(coPrice, alPrice);
                  
                  if (!coPrice) {
                      console.log('报错----');
                      if (repTime < 6) {
                          repTime++;
                          getPage();
                      } else {
                          repTime = 0;
                          console.error('获取不到价格');
                      }
                      return;
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

                  if (mail && transporter) {
                      mail.html = shtml;
                      mail.subject = priceData.upDateTime + "铜铝价格";
                      
                      try {
                          let img = fs.readFileSync("./public/images/example.jpg");
                          mail.attachments = [{
                              filename: "实时价格网站截图",
                              content: img,
                              cid: "img1"
                          }];
                      } catch (error) {
                          console.error('读取图片失败:', error);
                      }
                  }

                  // 铜价格保存
                  try {
                      const [copperExists] = await pool.query(
                          'SELECT * FROM coppers WHERE upDateTime = ?',
                          [priceData.upDateTime]
                      );
                      
                      if (copperExists.length === 0) {
                          await pool.query(
                              'INSERT INTO coppers (type, price, upDateTime, creatDate) VALUES (?, ?, ?, ?)',
                              [copper.type, copper.price, priceData.upDateTime, priceData.creatDate]
                          );
                      }
                  } catch (error) {
                      console.error('保存铜价格失败:', error);
                  }

                  // 铝价格保存
                  try {
                      const [aluminumExists] = await pool.query(
                          'SELECT * FROM aluminums WHERE upDateTime = ?',
                          [priceData.upDateTime]
                      );
                      
                      if (aluminumExists.length === 0) {
                          await pool.query(
                              'INSERT INTO aluminums (type, price, upDateTime, creatDate) VALUES (?, ?, ?, ?)',
                              [aluminum.type, aluminum.price, priceData.upDateTime, priceData.creatDate]
                          );
                      }
                      
                      if (nowCoPrice === coPrice && nowAlPrice === alPrice) {
                          console.log('价格相同');
                          return;
                      }
                      
                      if (mail && transporter) {
                          send(mail);
                      }
                      nowCoPrice = coPrice;
                      nowAlPrice = alPrice;
                  } catch (error) {
                      console.error('保存铝价格失败:', error);
                  }
              } catch (error) {
                  console.error('处理数据失败:', error);
              }
          });
      }).on("error", function (err) {
          console.log('加载失败---', err);
      });
    } catch (error) {
      console.error('爬虫执行失败:', error);
    }
  })(nowCoPrice, nowAlPrice);
}

// 发送邮件
function send(mail) {
  if (!transporter) {
    console.error('邮件传输器未初始化');
    return;
  }
  
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

app.get('/getPrice', async (req, res) => {
  try {
    // 获取最新的铜价格
    const [copperResult] = await pool.query(
      'SELECT * FROM coppers ORDER BY id DESC LIMIT 1'
    );
    
    if (copperResult.length > 0) {
      res.end(JSON.stringify(copperResult[0]));
    } else {
      res.end(JSON.stringify({}));
    }
  } catch (error) {
    console.error('获取价格失败:', error);
    res.end(JSON.stringify({}));
  }
});

app.get('/getPriceAll', async (req, res) => {
  try {
    const params = req.query;
    const num = params.pageSize * 1 || 10;
    const pageNo = params.pageNo * 1 || 1;
    const skip = (pageNo - 1) * num;
    
    // 获取总数
    const [countResult] = await pool.query(
      'SELECT COUNT(*) as total FROM coppers'
    );
    const total = countResult[0].total;
    const lastPageNum = Math.ceil(total / num);
    
    // 获取数据
    const [data] = await pool.query(
      'SELECT * FROM coppers ORDER BY id DESC LIMIT ? OFFSET ?',
      [num, skip]
    );
    
    const page = {
        page_no: pageNo + 1,
        page_size: num,
        total: total,
        lastPageNum: lastPageNum,
        data: [...data]
    };
    
    res.end(JSON.stringify(page));
  } catch (error) {
    console.error('获取价格列表失败:', error);
    res.end(JSON.stringify({}));
  }
});

var server = app.listen(3000, () => {
    var host = server.address().address;
    var port = server.address().port;
    console.log("应用实例，访问地址为 http://%s:%s", host, port);
});

// 截取网页生成图
// #依赖库
// yum install pango.x86_64 libXcomposite.x86_64 libXcursor.x86_64 libXdamage.x86_64 libXext.x86_64 libXi.x86_64 libXtst.x86_64 cups-libs.x86_64 libXScrnSaver.x86_64 libXrandr.x86_64 GConf2.x86_64 alsa-lib.x86_64 atk.x86_64 gtk3.x86_64 -y
// #字体
// yum install ipa-gothic-fonts xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-utils xorg-x11-fonts-cyrillic xorg-x11-fonts-Type1 xorg-x11-fonts-misc -y