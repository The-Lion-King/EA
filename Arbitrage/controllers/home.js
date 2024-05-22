const jwt = require('jsonwebtoken')
const assert = require('http-assert')
// const User = require('../models/User')

const { JWT_SECRET } = require('../config/')

class HomeController {
  static home(ctx) {
      ctx.state.fetch_time().then(res=>{
    console.log(res)
})
    ctx.body = 'hello world'
  }
  static async login(ctx) {
    const { username, password } = ctx.request.body
    //
    // // 1.根据用户名找用户
    // const user = await User.findOne({ username }).select('+password')
    // assert(user, 422, '用户不存在')
    // // 2.校验密码
    // const isValid = require('bcrypt').compareSync(password, user.password)
    // assert(isValid, 422, '密码错误')
    // const token = jwt.sign({ id: user._id }, JWT_SECRET)
    ctx.body = {
        text:'hello world'
    }
  }
  static async register(ctx) {
    ctx.body = 'Register Controller'
  }
}

module.exports = HomeController
