const express = require("express");
const app = express();
const https = require("https");
const fs = require("fs");
const cheerio = require("cheerio");
const nodemailer = require("nodemailer");
const schedule = require("node-schedule");
const targetUrl = "https://m.cnal.com/market/changjiang/";
// const puppeteer = require("puppeteer"); // 屏蔽截图相关

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

// 内存存储（模拟数据库）
let copperData = [];
let aluminumData = [];
let idCounter = 1;

// 定时器
const Rule2 = new schedule.RecurrenceRule();
Rule2.hour = [9, 10, 11];
Rule2.minute = [00, 15];
let repTime = 0;
let nowCoPrice = 0;
let nowAlPrice = 0;

// 定时任务
try {
  // schedule.scheduleJob(Rule2, () => {
    getPage();
  // });
} catch (error) {
  console.error('定时任务配置错误:', error);
}

function getPage() {
  (async (nowCoPrice, nowAlPrice) => {
    try {
      // 屏蔽 puppeteer 截图相关代码
      // const browser = await puppeteer.launch({
      //     headless: 'new',
      //     dumpio: false,
      //     ignoreHTTPSErrors: true,
      //     defaultViewport: {
      //         width: 1280,
      //         height: 960
      //     },
      //     args: ['--no-sandbox', '--disable-setuid-sandbox', '--enable-gpu',
      //         '--headless',
      //         '--disable-gpu',
      //         '--unlimited-storage',
      //         '--disable-dev-shm-usage',
      //         '--full-memory-crash-report',
      //         '--disable-extensions',
      //         '--mute-audio',
      //         '--no-zygote',
      //         '--no-first-run',
      //         '--start-maximized'
      //     ]
      // });

      // const page = await browser.newPage();
      // console.log('打开网址----------');
      // await page.goto(targetUrl, { timeout: 60000 });
      // console.log('打开网址----------001');
      
      // // 确保目录存在
      // if (!fs.existsSync('./public/images')) {
      //   fs.mkdirSync('./public/images', { recursive: true });
      // }
      
      // await page.screenshot({
      //     path: "./public/images/example.jpg",
      //     clip: {
      //         x: 0,
      //         y: 0,
      //         width: 800,
      //         height: 500
      //     }
      // });
      // console.log('打开网址----------002截图后');
      // await browser.close();
      // console.log('打开网址----------003浏览器关闭');
      
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
                      
                      // 屏蔽截图附件相关代码
                      // try {
                      //     let img = fs.readFileSync("./public/images/example.jpg");
                      //     mail.attachments = [{
                      //         filename: "实时价格网站截图",
                      //         content: img,
                      //         cid: "img1"
                      //     }];
                      // } catch (error) {
                      //     console.error('读取图片失败:', error);
                      // }
                  }

                  // 铜价格保存到内存
                  try {
                      const copperExists = copperData.find(item => item.upDateTime === priceData.upDateTime);
                      
                      if (!copperExists) {
                          copperData.push({
                              id: idCounter++,
                              type: copper.type,
                              price: copper.price,
                              upDateTime: priceData.upDateTime,
                              creatDate: priceData.creatDate
                          });
                      }
                  } catch (error) {
                      console.error('保存铜价格失败:', error);
                  }

                  // 铝价格保存到内存
                  try {
                      const aluminumExists = aluminumData.find(item => item.upDateTime === priceData.upDateTime);
                      
                      if (!aluminumExists) {
                          aluminumData.push({
                              id: idCounter++,
                              type: aluminum.type,
                              price: aluminum.price,
                              upDateTime: priceData.upDateTime,
                              creatDate: priceData.creatDate
                          });
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

app.get('/calculator/api/getPrice', async (req, res) => {
  try {
    // 获取最新的铜价格
    copperData.sort((a, b) => b.id - a.id);
    const copperResult = copperData[0];
    
    if (copperResult) {
      res.end(JSON.stringify(copperResult));
    } else {
      res.end(JSON.stringify({}));
    }
  } catch (error) {
    console.error('获取价格失败:', error);
    res.end(JSON.stringify({}));
  }
});

app.get('/calculator/api/getPriceAll', async (req, res) => {
  try {
    const params = req.query;
    const num = params.pageSize * 1 || 10;
    const pageNo = params.pageNo * 1 || 1;
    const skip = (pageNo - 1) * num;
    
    // 获取总数
    const total = copperData.length;
    const lastPageNum = Math.ceil(total / num);
    
    // 获取数据（按id倒序）
    const sortedData = [...copperData].sort((a, b) => b.id - a.id);
    const data = sortedData.slice(skip, skip + num);
    
    const page = {
        page_no: pageNo + 1,
        page_size: num,
        total: total,
        lastPageNum: lastPageNum,
        data: data
    };
    
    res.end(JSON.stringify(page));
  } catch (error) {
    console.error('获取价格列表失败:', error);
    res.end(JSON.stringify({}));
  }
});

// 代理接口：获取长江有色价格数据
app.get('/calculator/api/changjiang', (req, res) => {
  https.get(targetUrl, (response) => {
    let data = '';
    
    response.on('data', (chunk) => {
      data += chunk;
    });
    
    response.on('end', () => {
      try {
        // 使用cheerio解析HTML
        const $ = cheerio.load(data);
        
        // 提取价格数据
        const prices = [];
        $('table tr').each((index, element) => {
          if (index > 0) { // 跳过表头
            const tds = $(element).find('td');
            if (tds.length > 0) {
              const name = $(tds[0]).text().trim();
              const range = $(tds[1]).text().trim();
              const avg = $(tds[2]).text().trim();
              const change = $(tds[3]).text().trim();
              
              if (name && avg) {
                prices.push({
                  name: name,
                  range: range,
                  avg: avg,
                  change: change
                });
              }
            }
          }
        });
        
        res.json({
          success: true,
          data: prices,
          updateTime: new Date().toLocaleString('zh-CN')
        });
      } catch (error) {
        console.error('解析价格数据失败:', error);
        res.json({
          success: false,
          message: '解析数据失败',
          error: error.message
        });
      }
    });
  }).on('error', (error) => {
    console.error('获取长江有色数据失败:', error);
    res.json({
      success: false,
      message: '获取数据失败',
      error: error.message
    });
  });
});

const PORT = process.env.PORT || process.env.port || 3000;

var server = app.listen(PORT, () => {
    var host = server.address().address;
    var port = server.address().port;
    var hostDisplay = host === '::' ? 'localhost' : host;
    console.log("========================================");
    console.log("应用已启动");
    console.log("访问地址: http://%s:%s", hostDisplay, port);
    console.log("使用端口: %d (环境变量 PORT)", port);
    console.log("存储模式: 内存存储");
    console.log("========================================");
});