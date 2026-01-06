local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Path = __IO.Path
    local __Directory = __IO.Directory
    local __File = __IO.File
    local __SearchOption = __IO.SearchOption

local mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'
local mod_path = __Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path)

local function clear_folder_of_extensions(directory, ...)
    local full_directory = __Path.Combine(mod_path, directory)
    if not __Directory.Exists(full_directory) then return end
    for _i,k in pairs{...} do
        local files = __Directory.GetFiles(full_directory, '*'.. k, __SearchOption.TopDirectoryOnly)

        for file in luanet.each(files) do
            __File.Delete(file)
        end
    end
end

local function delete_index(directory)
    if __File.Exists(__Path.Combine(mod_path, directory, "index.idx")) then
        __File.Delete(__Path.Combine(mod_path, directory, "index.idx"))
    end
end

return function()
    if __File.Exists(__Path.Combine(mod_path, "Data", "Universal.jsonpatch")) then
        __File.Delete(__Path.Combine(mod_path, "Data", "Universal.jsonpatch"))
    end

    clear_folder_of_extensions("Content/Chara", ".chara")
    clear_folder_of_extensions("Content/Portrait", ".portrait")

    clear_folder_of_extensions("Data/Monster", ".json", ".jsonpatch")
    delete_index("Data/Monster")
    clear_folder_of_extensions("Data/Element", ".json", ".jsonpatch")
    delete_index("Data/Element")
    clear_folder_of_extensions("Data/Skill", ".json", ".jsonpatch")
    delete_index("Data/Skill")
end