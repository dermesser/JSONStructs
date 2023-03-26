module JSONStructs

include("jsonparser.jl")
include("metaparser.jl")

import .Parser: Optional, parse_struct, parse_value
import .Metaparser: @json_parseable

export @json_parseable
export Optional, parse_value, parse_struct

end # module JSONStructs
