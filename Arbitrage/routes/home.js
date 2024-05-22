const Router = require('koa-router')
const { home, login, register } = require('../controllers/home')

const router = new Router()

router.get('/', home)
router.post('/login', login)
router.post('/register', register)

module.exports = router
