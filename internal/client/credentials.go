package kessel

import (
	"context"
	"fmt"

	"github.com/project-kessel/kessel-sdk-go/kessel/auth"
	"google.golang.org/grpc"
)

// insecureBearerCreds implements credentials.PerRPCCredentials and adds a
// Bearer token to outgoing gRPC metadata. RequireTransportSecurity returns false
// so the token can be sent over an insecure (non-TLS) connection, matching
// inventory-api's WithInsecureBearerToken behavior when talking to relations-api.
type insecureBearerCreds struct {
	token string
}

// GetRequestMetadata returns the Authorization header with the bearer token.
func (c insecureBearerCreds) GetRequestMetadata(_ context.Context, _ ...string) (map[string]string, error) {
	if c.token == "" {
		return nil, nil
	}
	return map[string]string{
		"authorization": fmt.Sprintf("Bearer %s", c.token),
	}, nil
}

// RequireTransportSecurity returns false to allow sending the token over insecure gRPC.
func (insecureBearerCreds) RequireTransportSecurity() bool {
	return false
}

// insecureOAuth2PerRPCCreds implements credentials.PerRPCCredentials by
// obtaining a token via OAuth2 client credentials and attaching it to each RPC.
// RequireTransportSecurity returns false so it can be used over insecure gRPC.
// Stores client id/secret/endpoint so no pointer to stack-allocated auth is kept.
type insecureOAuth2PerRPCCreds struct {
	clientID       string
	clientSecret   string
	tokenEndpoint  string
}

// GetRequestMetadata fetches an OAuth2 token and returns the Authorization header.
func (c *insecureOAuth2PerRPCCreds) GetRequestMetadata(ctx context.Context, _ ...string) (map[string]string, error) {
	oauthCredentials := auth.NewOAuth2ClientCredentials(c.clientID, c.clientSecret, c.tokenEndpoint)
	tok, err := oauthCredentials.GetToken(ctx, auth.GetTokenOptions{})
	if err != nil {
		return nil, err
	}
	return map[string]string{
		"authorization": fmt.Sprintf("Bearer %s", tok.AccessToken),
	}, nil
}

// RequireTransportSecurity returns false to allow use over insecure gRPC.
func (*insecureOAuth2PerRPCCreds) RequireTransportSecurity() bool {
	return false
}

// WithInsecureBearerToken returns a grpc.CallOption that adds a Bearer token
// to the request metadata and allows insecure transport (no TLS).
// Use this when connecting to inventory-api over plain gRPC but still sending a JWT.
func WithInsecureBearerToken(token string) grpc.CallOption {
	return grpc.PerRPCCredentials(insecureBearerCreds{token: token})
}
