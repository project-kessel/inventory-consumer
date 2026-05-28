package kessel

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/project-kessel/kessel-sdk-go/kessel/auth"
	kesselgrpc "github.com/project-kessel/kessel-sdk-go/kessel/grpc"
	"github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

type ClientProvider interface {
	ReportResource(request *v1beta2.ReportResourceRequest) (*v1beta2.ReportResourceResponse, error)
	DeleteResource(request *v1beta2.DeleteResourceRequest) (*v1beta2.DeleteResourceResponse, error)
	IsEnabled() bool
}

type KesselClient struct {
	v1beta2.KesselInventoryServiceClient
	Enabled     bool
	AuthEnabled bool
	// callOpts are applied to each RPC when set (e.g. Per-RPC JWT over insecure gRPC).
	callOpts []grpc.CallOption
}

func New(c CompletedConfig, logger *log.Helper) (*KesselClient, error) {
	logger.Info("Setting up Inventory API client")
	var client v1beta2.KesselInventoryServiceClient
	var callOpts []grpc.CallOption
	var err error

	if !c.Enabled {
		logger.Info("ClientProvider enabled: ", c.Enabled)
		return &KesselClient{Enabled: false}, nil
	}

	// TLS + OIDC: use SDK Authenticated with channel credentials.
	if c.EnableOidcAuth && !c.Insecure {
		oauthCredentials := auth.NewOAuth2ClientCredentials(c.ClientId, c.ClientSecret, c.TokenEndpoint)
		channelCreds, err := configureTLS(c.CACertFile)
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to setup transport credentials for TLS: %w", err)
		}
		client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).
			Authenticated(kesselgrpc.OAuth2CallCredentials(&oauthCredentials), channelCreds).Build()
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to create gRPC client: %w", err)
		}
	} else if c.Insecure {
		// Insecure gRPC: build with SDK Insecure(), then attach JWT via Per-RPC credentials (no SDK changes).
		client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).Insecure().Build()
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to create inventory client: %w", err)
		}
		if c.BearerToken != "" {
			callOpts = []grpc.CallOption{WithInsecureBearerToken(c.BearerToken)}
		} else if c.EnableOidcAuth {
			callOpts = []grpc.CallOption{grpc.PerRPCCredentials(&insecureOAuth2PerRPCCreds{
				clientID: c.ClientId, clientSecret: c.ClientSecret, tokenEndpoint: c.TokenEndpoint,
			})}
		}
	} else {
		channelCreds, err := configureTLS(c.CACertFile)
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to setup transport credentials for TLS: %w", err)
		}
		client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).Unauthenticated(channelCreds).Build()
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to create inventory client: %w", err)
		}
	}
	return &KesselClient{
		KesselInventoryServiceClient: client,
		Enabled:                      c.Enabled,
		AuthEnabled:                  c.EnableOidcAuth,
		callOpts:                     callOpts,
	}, nil
}

func (k *KesselClient) ReportResource(request *v1beta2.ReportResourceRequest) (*v1beta2.ReportResourceResponse, error) {
	resp, err := k.KesselInventoryServiceClient.ReportResource(context.Background(), request, k.callOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to report resource: %w", err)
	}
	return resp, nil
}

func (k *KesselClient) DeleteResource(request *v1beta2.DeleteResourceRequest) (*v1beta2.DeleteResourceResponse, error) {
	resp, err := k.KesselInventoryServiceClient.DeleteResource(context.Background(), request, k.callOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to delete resource: %w", err)
	}
	return resp, nil
}

func (k *KesselClient) IsEnabled() bool {
	return k.Enabled
}

func configureTLS(caPath string) (credentials.TransportCredentials, error) {
	caCert, err := os.ReadFile(caPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read the ca cert file at provided path %s: %w", caPath, err)
	}
	return configureTLSFromData(caCert)
}

// configureTLSFromData is a means to facilitate both test and production use of the client
func configureTLSFromData(caCert []byte) (credentials.TransportCredentials, error) {
	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM(caCert) {
		return nil, fmt.Errorf("failed to add the server CA's certificate to new cert pool")
	}
	config := &tls.Config{
		RootCAs: certPool,
	}
	return credentials.NewTLS(config), nil
}
