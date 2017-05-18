variable "FASTLY_API_KEY" {}
variable "FASTLY_DOMAIN" {}
variable "FASTLY_SESSION_SECRET_KEY" {}

data "template_file" "vcl" {
  template = "${file("${path.module}/main.vcl")}"

  vars {
    SESSION_SECRET_KEY = "${var.FASTLY_SESSION_SECRET_KEY}"
  }
}

provider fastly {
  api_key = "${var.FASTLY_API_KEY}"
}

resource "fastly_service_v1" "jwt-vcl" {
  name = "${var.FASTLY_DOMAIN}"

  domain {
    name = "${var.FASTLY_DOMAIN}"
  }

  backend {
    address = "127.0.0.1"
    name    = "localhost"
    port    = 80
  }

  vcl {
    name    = "main"
    content = "${data.template_file.vcl.rendered}"
    main    = true
  }

  force_destroy = true
}
