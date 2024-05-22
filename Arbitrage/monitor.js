const ccxt = require("ccxt");

const apiKey = 'c96wM4mgPC0CaFCx4FAEdpTY5W8tYzMfG1pxOFFly94FvdPOD78t7xkjKlTKZ0FB'
const secret = 'gnEt2rN0ibTkLFDfny3hi7V7HxTHhZNvViteGdMlrjHaYiuYHNVTFknbEvRyk9xt'

const exchange = new ccxt.binance ({
    'apiKey': apiKey,
    'secret': secret,
})

const getRate = async ()=>{
    const rate = await exchange.fetchFundingRates(['BTC/USDT:USDT'])
    const balance = await exchange.fetchBalance({marginMode:'isolated'})
    console.log(rate,balance)
}


getRate()




