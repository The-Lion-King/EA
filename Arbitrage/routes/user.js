const Router = require('koa-router')
const jwt = require('koa-jwt')
const {
  create,
  find,
  findById,
  update,
  delete: del,
} = require('../controllers/user')

const router = new Router({ prefix: '/users' })
const { JWT_SECRET } = require('../config/')

const auth = jwt({ JWT_SECRET })

router.post('/', create)
router.get('/', find)
router.get('/:id', findById)
router.put('/:id', auth, update)
router.delete('/:id', auth, del)

module.exports = router
