open! Core

module Media_item = struct
  type t = {
    id : string;
    filename : string;
    description : string option; [@yojson.option]
    product_url : string option; [@yojson.option] [@key "productURL"]
    base_url : string option; [@yojson.option] [@key "baseURL"]
    mime_type : string option; [@yojson.option] [@key "mimeType"]
  }
  [@@deriving sexp, yojson] [@@yojson.allow_extra_fields]
end
