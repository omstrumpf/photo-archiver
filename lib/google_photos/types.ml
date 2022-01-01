open! Core

module Media_metadata = struct
  type t = { creation_time : string [@key "creationTime"] }
  [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
end

module Media_item = struct
  type t = {
    id : string;
    filename : string;
    description : string option; [@yojson.option]
    product_url : string option; [@yojson.option] [@key "productURL"]
    base_url : string option; [@yojson.option] [@key "baseURL"]
    mime_type : string option; [@yojson.option] [@key "mimeType"]
    media_metadata : Media_metadata.t; [@key "mediaMetadata"]
  }
  [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
end
