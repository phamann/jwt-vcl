table env {
    "session_key": "${SESSION_SECRET_KEY}"
}

sub vcl_recv {
    #FASTLY recv

    if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
        return(pass);
    }

    // Error if no session key in env dictionary
    if(!table.lookup(env, "session_key")) {
        error 500;
    }

    // Generate synth
    if(req.url ~ "generate") {
        error 901;
    }

    // Validate token
    if(req.url ~ "validate") {
        // Ensure token exists and parse into regex
        if (req.http.X-JWT !~ "^([a-zA-Z0-9\-_]+)?\.([a-zA-Z0-9\-_]+)?\.([a-zA-Z0-9\-_]+)?$") {
            // Forbidden
            error 403 "Forbidden";
        }

        // Extract token header, payload and signature
        set req.http.X-JWT-Header = re.group.1;
        set req.http.X-JWT-Payload = re.group.2;
        set req.http.X-JWT-Signature = digest.base64url_nopad_decode(re.group.3);
        set req.http.X-JWT-Valid-Signature = digest.hmac_sha256(table.lookup(env, "session_key"), req.http.X-JWT-Header "." req.http.X-JWT-Payload);

        // Validate signature
        if(digest.secure_is_equal(req.http.X-JWT-Signature, req.http.X-JWT-Valid-Signature)) {
            // Decode payload
            set req.http.X-JWT-Payload = digest.base64url_nopad_decode(req.http.X-JWT-Payload);
            set req.http.X-JWT-Expires = regsub(req.http.X-JWT-Payload, {"^.*?"exp"\s*?:\s*?([0-9]+).*?$"}, "\1");

            // Validate expiration
            if (time.is_after(now, std.integer2time(std.atoi(req.http.X-JWT-Expires)))) {
               // Unauthorized
               error 401 "Unauthorized";
            }

            // OK
            error 902;
        } else {
            // Forbidden
            error 403 "Forbidden";
        }
    }

    return(lookup);
}

sub vcl_error {
    #FASTLY error

    // Generate JWT token
    if (obj.status == 901) {
        set obj.status = 200;
        set obj.response = "OK";
        set obj.http.Content-Type = "application/json";

        set obj.http.X-UUID = randomstr(8, "0123456789abcdef") "-" randomstr(4, "0123456789abcdef") "-4" randomstr(3, "0123456789abcdef") "-" randomstr(1, "89ab") randomstr(3, "0123456789abcdef") "-" randomstr(12, "0123456789abcdef");

        set obj.http.X-JWT-Issued = now.sec;
        set obj.http.X-JWT-Expires = strftime({"%s"}, time.add(now, 60s));

        set obj.http.X-JWT-Header = digest.base64url_nopad({"{"alg":"HS256","typ":"JWT""}{"}"});
        set obj.http.X-JWT-Payload = digest.base64url_nopad({"{"sub":""} obj.http.X-UUID {"","exp":"} obj.http.X-JWT-Expires {","iat":"} obj.http.X-JWT-Issued {","iss":"Fastly""}{"}"});
        set obj.http.X-JWT-Signature = digest.base64url_nopad(digest.hmac_sha256(table.lookup(env, "session_key"), obj.http.X-JWT-Header "." obj.http.X-JWT-Payload));

        set obj.http.X-JWT = obj.http.X-JWT-Header "." obj.http.X-JWT-Payload "." obj.http.X-JWT-Signature;

        unset obj.http.X-UUID;
        unset obj.http.X-JWT-Issued;
        unset obj.http.X-JWT-Expires;
        unset obj.http.X-JWT-Header;
        unset obj.http.X-JWT-payload;
        unset obj.http.X-JWT-Signature;

        synthetic {"{ "token": ""} obj.http.X-JWT {"" }"};
        return(deliver);
    }

    // Valid token
    if (obj.status == 902) {
        set obj.status = 200;
        set obj.response = "OK";
        set obj.http.Content-Type = "application/json";

        synthetic {"{ "token": ""} req.http.X-JWT {"" }"};
        return(deliver);
    }

}
