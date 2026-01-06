local shoehorn_placeholder_start = "!shoehorn{"
local shoehorn_placeholder_end = "}"

local shoehorn_placeholder_start_len = shoehorn_placeholder_start:len()
local shoehorn_placeholder_end_len = shoehorn_placeholder_end:len()

local function exists(data_type, id)
    return _DATA.DataIndices[data_type]:ContainsKey(id)
end

---@param str string
---@param local_renames {[string]: string?}
---@param shoehorn Wintermourn.Shoehorn.Global
return function(data_type, str, local_renames, shoehorn)
    if
        str:sub(1, shoehorn_placeholder_start_len) == shoehorn_placeholder_start and
        str:sub(- shoehorn_placeholder_end_len) == shoehorn_placeholder_end
    then
        local inner = str:sub(shoehorn_placeholder_start_len + 1, -shoehorn_placeholder_end_len - 1)

        for entry in inner:gmatch "[^|]+" do
            local namespace, identifier = entry:match "^([^:]+):(.+)$"
            if not identifier then namespace = nil; identifier = entry end

            if namespace then
                if shoehorn.shared_identifiers[namespace] then
                    local type_matched_ids = shoehorn.shared_identifiers[namespace][data_type:ToString():lower()]
                    local potential_id = type_matched_ids[identifier]
                    if potential_id then
                        return potential_id
                    end
                end
            else
                if local_renames[identifier] then
                    return local_renames[identifier]
                elseif exists(data_type, identifier) then
                    return identifier
                end
            end
        end
    end

    return local_renames[str] or (exists(data_type, str) and str)
end