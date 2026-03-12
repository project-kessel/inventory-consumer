package kessel

import (
	"fmt"

	"github.com/spf13/pflag"
)

type Options struct {
	Enabled        bool   `mapstructure:"enabled"`
	InventoryURL   string `mapstructure:"url"`
	Insecure       bool   `mapstructure:"insecure-client"`
	CACertFile     string `mapstructure:"ca-cert-file"`
	EnableOidcAuth bool   `mapstructure:"enable-oidc-auth"`
	ClientId       string `mapstructure:"client-id"`
	ClientSecret   string `mapstructure:"client-secret"`
	TokenEndpoint  string `mapstructure:"sso-token-endpoint"`
	// BearerToken is an optional static JWT sent as Per-RPC credentials when Insecure is true.
	// Allows sending a valid JWT over insecure gRPC (no TLS) without changing the SDK.
	BearerToken string `mapstructure:"bearer-token"`
}

func NewOptions() *Options {
	return &Options{
		Enabled:        true,
		Insecure:       false,
		EnableOidcAuth: false,
	}
}

func (o *Options) AddFlags(fs *pflag.FlagSet, prefix string) {
	if prefix != "" {
		prefix = prefix + "."
	}
	fs.BoolVar(&o.Enabled, prefix+"enabled", o.Enabled, "enable the kessel inventory grpc client")
	fs.StringVar(&o.InventoryURL, prefix+"url", o.InventoryURL, "gRPC endpoint of the kessel inventory service.")
	fs.BoolVar(&o.Insecure, prefix+"insecure-client", o.Insecure, "the http client that connects to kessel should not verify certificates.")
	fs.StringVar(&o.CACertFile, prefix+"ca-cert-file", o.CACertFile, "path to the CA cert file for TLS communication with the Kessel Inventory API.")
	fs.StringVar(&o.ClientId, prefix+"client-id", o.ClientId, "service account client id")
	fs.StringVar(&o.ClientSecret, prefix+"client-secret", o.ClientSecret, "service account secret")
	fs.StringVar(&o.TokenEndpoint, prefix+"sso-token-endpoint", o.TokenEndpoint, "sso token endpoint for authentication")
	fs.BoolVar(&o.EnableOidcAuth, prefix+"enable-oidc-auth", o.EnableOidcAuth, "enable oidc token auth to connect with Inventory API service")
	fs.StringVar(&o.BearerToken, prefix+"bearer-token", o.BearerToken, "optional static JWT sent as Per-RPC credentials when using insecure gRPC to Inventory API")

}

func (o *Options) Validate() []error {
	var errs []error

	if len(o.InventoryURL) == 0 && o.Enabled {
		errs = append(errs, fmt.Errorf("kessel url may not be empty"))
	}

	// Insecure + JWT (BearerToken or OIDC) is allowed: JWT is sent via Per-RPC credentials.
	if o.EnableOidcAuth && o.Insecure && o.BearerToken != "" {
		errs = append(errs, fmt.Errorf("cannot set both bearer-token and enable-oidc-auth when insecure"))
	}

	return errs
}

func (o *Options) Complete() []error {
	var errs []error

	return errs
}
