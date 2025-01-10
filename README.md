# rbx-json  

custom json encoding/decoding library for Roblox & luau, supporting Roblox types like `Vector3`, `UDim2`, etc.  

## installation  

get the latest release from:  
- [github releases](https://github.com/dumpstring/rbx-json/releases/latest)  
- Build it yourself using Rojo: `rojo build -o json.rbxm`  

& add it to your game via roblox studio drag & drop.
## usage  

```lua  
local json = require(path.to.rbx-json)
```  

use `json.encode` to serialize a value to json, and `json.decode` to deserialize a json string into luau data types.  

### encoding  

```lua  
local encoded = json.encode({
    name = "dumpstring",
    position = Vector3.new(1, 2, 3),
    isActive = true
}, true) -- pretty print enabled
print(encoded)
-- Output: {
--   "name": "dumpstring",
--   "position": "[Vector3 1,2,3]",
--   "isActive": true
-- }
```  

### decoding  

```lua  
local decoded = json.decode('{"name": "dumpstring", "position": "[Vector3 1,2,3]"}')
print(decoded.name) -- "dumpstring"
print(decoded.position) -- Vector3.new(1, 2, 3)
```  

## supported data types  

the library supports standard json types (`string`, `number`, `boolean`, `null`, `array`) and additional Roblox specific types:  
- `Vector2`  
- `Vector3`  
- `UDim`  
- `UDim2`  
- `Color3`  
- `CFrame`  
- `Instance` (serialized as `"[Instance {base64Name.base64Name.etc.}]"`, supports unicode names.)  
- functions (serialized as `"function"`)  

## configuration  

no configuration is required to use the library, but `json.encode` supports optional arguments:  
```lua  
function json.encode(value: any, pretty: boolean?, indentLevel: number?, encodeInstancePaths: boolean?): string
```  
- `pretty` (boolean): enables pretty printed json output. defaults to `false`.
- `indentLevel` (number): controls the initial indentation level. defaults to `2`.
- `encodeInstancePaths` (boolean): controls whether instance paths are encoded. defaults to `false`.

## api  

### `json.encode(value: any, pretty: boolean?, indentLevel: number?, encodeInstancePaths: boolean?): string`  

encodes a luau value into a json string.  

### `json.decode(json: string): any`  

decodes a json string into a luau value.  

## error handling  

### encoding errors  
- non serializable types like userdata will throw an error.  
- circular table references are not allowed and will raise an assertion failure.  

### decoding errors  
- invalid json will throw a descriptive error with line and column numbers for debugging.  
- trailing characters in the json string will also raise an error.  

# [LICENSE](https://github.com/dumpstring/rbx-json/blob/main/LICENSE)  
