require 'CLRPackage'

local constants = {
    valid_replace_types = {
        monsters = {
            replace = true,
            --merge = true,
            rename = true,
            ignore = true
        },
        elements = {
            replace = true,
            merge = true,
            rename = true,
            ignore = true
        },
        skills = {
            replace = true,
            rename = true,
            ignore = true
        },
        intrinsics = {
            replace = true,
            rename = true,
            ignore = true
        },
        items = {
            replace = true,
            rename = true,
            ignore = true
        }
    },
    hash_order = {
        "monsters",
        "elements",
        "skills"
    }
}

local success, mtk = pcall(require, 'mentoolkit')
if success then
    mtk .add_to_menu("top_menu", '[$shoehorn:topmenu]', function ()
        require 'wintermourn-shoehorn.src.ui.manager' .open()
    end)
end
constants.load_all_shoehorns = mtk == nil

local this_mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'

local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Directory = __IO.Directory
    local __Path = __IO.Path
    local __File = __IO.File

local __DataType = RogueEssence.Data.DataManager.DataType

local function scan_for_shoehorns(path)
    local target = __Path.Combine(path, "Shoehorns")
    if not __Directory.Exists(target) then return {} end

    local entries = __Directory.GetFileSystemEntries(target)

    local output = {}
    local shoepath
    for entry in luanet.each(entries) do
        shoepath = __Path.Combine(entry, ".shoehorn")
        if __Directory.Exists(entry) and __File.Exists(shoepath) then
            table.insert(output, entry)
        end
    end

    return output
end

---@class Wintermourn.Shoehorn.Global
local shoehorn = {
    packs = {},
    shared_identifiers = {},
    registered_identifiers = {
        elements = {},
        monsters = {},
        skills = {},
        intrinsics = {},
        items = {}
    },
    data_tags = {
        monsters = {},
        items = {}
    }
}

local build_shoehorn_data = require 'wintermourn-shoehorn.src.build_data'

for mod in luanet.each(RogueEssence.PathMod.Mods) do
    local shoehorns = scan_for_shoehorns(__Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path))
    for _,folder in pairs(shoehorns) do
        local dat = build_shoehorn_data(folder, constants)

        if dat then
            table.insert(shoehorn.packs, dat)
            print("Shoehorn found: ", dat.name)
            print((' "%s"'):format (dat.description) )
            print("Authors:")
            for _i,k in pairs(dat.authors) do
                print('-', k)
            end

            if dat.public_id then
                shoehorn.shared_identifiers[dat.public_id] = {
                    element = {}, monster = {}, item = {}, skill = {}, intrinsic = {}
                }
            end

            if dat.registrations then
                print("Registrations:")
                for i,k in pairs(dat.registrations) do
                    print(("  %s:"):format(i))
                    for _c,v in pairs(k) do
                        --shoehorn.known_names[v.preferred_id] = true
                        print(("    - %s"):format(v.preferred_id))
                    end
                end
            end
        end
    end

end
    
local remembered_hashes = {}
local has_data_changed = false

local element_hash = require 'wintermourn-shoehorn.src.hashing.elements' (shoehorn.packs)
local monster_hash = require 'wintermourn-shoehorn.src.hashing.monsters' (shoehorn.packs)
local skills_hash = require 'wintermourn-shoehorn.src.hashing.skills' (shoehorn.packs)

local current_hash = 1
if not __File.Exists(__Path.Combine(RogueEssence.PathMod.APP_PATH, this_mod.Path, "shoehorn.cache")) then
    has_data_changed = true
else
    for line in io.lines(__Path.Combine(RogueEssence.PathMod.APP_PATH, this_mod.Path, "shoehorn.cache")) do
        if constants.hash_order[current_hash] then
            remembered_hashes[constants.hash_order[current_hash]] = line
        else break
        end
        current_hash = current_hash + 1
    end

    if element_hash ~= remembered_hashes.elements then has_data_changed = true end
    if monster_hash ~= remembered_hashes.monsters then has_data_changed = true end
    if skills_hash ~= remembered_hashes.skills then has_data_changed = true end
end

if has_data_changed then
    require 'wintermourn-shoehorn.src.clear' ()
    _DATA:LoadIndex(__DataType.Monster)

    for _i, pack in pairs(shoehorn.packs) do
        if not pack.registrations then 
            goto skip_loading
        end
        ---@class Wintermourn.Shoehorn.LocalRenames
        local renamed_entries = {}

        renamed_entries.elements = require 'wintermourn-shoehorn.src.data_loaders.elements' (shoehorn, pack)
        renamed_entries.skills = require 'wintermourn-shoehorn.src.data_loaders.skills' (shoehorn, pack, renamed_entries)
        require 'wintermourn-shoehorn.src.data_loaders.monsters' (shoehorn, pack, renamed_entries)
        ::skip_loading::
    end

    print("[shoehorn] reindexing")
    local reindex = require 'wintermourn-shoehorn.util.reindex'
    reindex (__DataType.Element)
    reindex (__DataType.Monster)
    reindex (__DataType.Skill)

    local new_cache = io.open(__Path.Combine(RogueEssence.PathMod.APP_PATH, this_mod.Path, "shoehorn.cache"), "w") --[[@as file]]
    new_cache:write(monster_hash ..'\n')
    new_cache:write(element_hash ..'\n')
    new_cache:write(skills_hash ..'\n')
    new_cache:flush()
    new_cache:close()

    _DATA:InitDataIndices()
end