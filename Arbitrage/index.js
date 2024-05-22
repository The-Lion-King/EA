const path = require('path')
const Koa = require('koa')
const bobyParser = require('koa-bodyparser')
const koaStatic = require('koa-static')
const cors = require('@koa/cors')
const error = require('koa-json-error')
const parameter = require('koa-parameter')
const routing = require('./routes')
const ccxt = require('ccxt')
//const db = require('./db/')

const app = new Koa()

// db.connect()




app.use(async (ctx, next)=>{
    ctx.state = exchange;
    await next()
})
app.use(
  error({
    postFormat: (e, { stack, ...rest }) =>
      process.env.NODE_ENV === 'production' ? rest : { stack, ...rest },
  }),
)
app.use(bobyParser())
app.use(koaStatic(path.join(__dirname, 'public')))
app.use(cors())
app.use(parameter(app))
routing(app)

app.listen(3000, () => {
  console.log('3000端口已启动')
})
