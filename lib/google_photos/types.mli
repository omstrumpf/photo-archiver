open! Core

module Media_metadata : sig
  type t = { creation_time : string } [@@deriving sexp, yojson]
end

module Media_item : sig
  type t = {
    id : string;
    filename : string;
    description : string option;
    product_url : string option;
    base_url : string option;
    mime_type : string option;
    media_metadata : Media_metadata.t option;
  }
  [@@deriving sexp, yojson]
end
