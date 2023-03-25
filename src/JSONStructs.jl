module JSONStructs

include("metaparser.jl")
include("jsonparser.jl")

import .Parser: parse_struct, parse_value
import .Metaparser: @json_parseable

export @json_parseable
export parse_value, parse_struct

end # module JSONStructs
