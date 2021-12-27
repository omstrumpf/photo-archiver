open! Core

module Media_item : sig
  type t = {
    id : string;
    filename : string;
    description : string option;
    product_url : string option;
    base_url : string option;
    mime_type : string option;
  }
  [@@deriving sexp, yojson]
end
