local __Dictionary = luanet.import_type 'System.Collections.Generic.Dictionary`2'
local __Object = luanet.import_type 'System.Object'
local __String = luanet.import_type 'System.String'
local __Type = luanet.import_type 'System.Type'
local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Path = __IO.Path
    local __Directory = __IO.Directory
    local __File = __IO.File
    local __FileStream = __IO.FileStream

local __DataManager_LoadModData = luanet.ctype(RogueEssence.Data.DataManager):GetMethod("LoadModData"):MakeGenericMethod(
    luanet.make_array(__Type, {__Type.GetType 'RogueEssence.Data.IEntryData, RogueEssence'})
);

local mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'
local indexArgs = luanet.make_array(__Object, {
    mod, '', '', RogueEssence.Data.DataManager.DATA_EXT
});

local mod_path = __Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path)

return function(type)
    local index_path = mod_path .. '/Data/'.. type:ToString() ..'/index.idx'
    local stream = __FileStream(
        index_path,
        __IO.FileMode.Create,
        __IO.FileAccess.Write,
        __IO.FileShare.None
    )
    local entries = LUA_ENGINE:MakeGenericType(
        __Dictionary,
        {
            __String,
            RogueEssence.Data.EntrySummary
        },
        {}
    )

    local files = __Directory.GetFiles(__Path.Combine(mod_path, "Data", type:ToString()), '*')
    local dir, filename, extension, data

    print ("reindex >> creating entry summaries")

    indexArgs[1] = 'Data/'.. type:ToString() ..'/'
    for i = 0, files.Length - 1 do
        dir = files[i]
        filename = __Path.GetFileNameWithoutExtension(dir)
        extension = __Path.GetExtension(dir)

        if extension == RogueEssence.Data.DataManager.DATA_EXT or extension == RogueEssence.Data.DataManager.PATCH_EXT then

            print ("reindex >>> file ".. filename)
            indexArgs[2] = filename
            data = __DataManager_LoadModData:Invoke(nil, indexArgs)
            if data then
                entries[filename] = data:GenerateEntrySummary()
            end
        end
    end

    print ("reindex >> flush time")

    if entries.Count > 0 then
        RogueEssence.Data.Serializer.SerializeData(stream, entries)
        stream:Flush()
        stream:Close()
    else
        stream:Close()
        __File.Delete(index_path)
    end
end