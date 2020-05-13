package api

import (
	cg "github.com/cdyfng/coind/cointop/common/api/impl/coingecko"
	cmc "github.com/cdyfng/coind/cointop/common/api/impl/coinmarketcap"
)

// NewCMC new CoinMarketCap API
func NewCMC(apiKey string) Interface {
	return cmc.NewCMC(apiKey)
}

// NewCC new CryptoCompare API
func NewCC() {
	// TODO
}

// NewCG new CoinGecko API
func NewCG() Interface {
	return cg.NewCoinGecko()
}
