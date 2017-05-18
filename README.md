# jwt-vcl
Demo to generate, decode and validate JWT tokens at the edge using [Fastly](https://www.fastly.com/) VCL.

JSON Web Tokens are an open, industry standard [RFC 7519](https://tools.ietf.org/html/rfc7519) method for representing claims securely between two parties.

## Why?

#### Validation
You may have user requests that already contain a generated JWT (for example in a Cookie) and want to validate them quickly on the edge before granting access to a backend.
Useful when:
- You have a different auth/session backend that you want to validate user claims against before restarting request and sending to service backend.
- You want a light stateless endpoint you can call client-side to quickly to validte a user claim.

### Generation
You want to generate them on the edge for short-lived, one-time password type scenarios. 

Useful when:
- The tokens are short-lived. They only need to be valid for a few minutes, to allow Edge to validate certain requests such as data mutation. 
- The token is only expected to be used once. The application server would issue a new token for every requests/response, so any one token is just used to request a resource or POST data once, and then thrown away. There's no persistent state, at all.

## Install:
- [Install Terraform](https://www.terraform.io/downloads.html)
- Generate a new session secret key `openssl rand -base64 32`
- Create and edit a `terraform.tfvars` in the projetc root with your [Fastly API token](https://docs.fastly.com/api/auth#tokens), secret key and domain name.

terraform.tfvars
```env
FASTLY_API_KEY = "<MY API TOKEN>"

FASTLY_SESSION_SECRET_KEY = "<MY SECRET KEY>"

FASTLY_DOMAIN = "<MY DOMAIN NAME>"
```

## Usage:
To generate a one-time JWT token:
```sh
curl -X GET http://<MY_SERVICE_DOMAIN>/generate
```

To validate the token:
```
curl -X GET http://<MY_SERVICE_DOMAIN>/validate -H 'X-JWT: <MY_TOKEN>'
```

The VCL checks for two things:
- Does the JWT signature match the correct signature of the token?
- Is the current time greater than the expiration time specified in the token?

If the signature is invalid, we return a 403. If the signature is valid but the expiration time has elapsed, we return a 410. It is not possible for a malicious user to modify the expiration time of their token, as if they did, the signature would no longer match.

To see token expiration, wait 1-2 minutes and try validate again.

## Notes:
- In the demo we have used an inline edge dictionary in the vcl file and Terraform templating to store and pass you secret key to the vcl. Whilst this is suffcient we reccomend generating an Edge Dictionary using the API instead, as this abstracts the sotrage of the key/value pairs out of vcl and allows you to man age the key via API calls out of the lifecycle of your vcl deployment.
- This **shouldn't** be used as a replacement for proper session management and storage.
