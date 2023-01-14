local _, MySlot = ...

local L = MySlot.L

local crc32 = MySlot.crc32
local base64 = MySlot.base64

local pblua = MySlot.luapb
local _MySlot = pblua.load_proto_ast(MySlot.ast)


local MYSLOT_AUTHOR = "xjq314"


local MYSLOT_VER = 30
local DEWATER_VER = 1 
local MYSLOT_ALLOW_VER = {MYSLOT_VER}

-- local MYSLOT_IS_DEBUG = true
local MYSLOT_LINE_SEP = IsWindowsClient() and "\r\n" or "\n"
local MYSLOT_MAX_ACTIONBAR = 132

-- {{{ SLOT TYPE
local MYSLOT_SPELL = _MySlot.Slot.SlotType.SPELL
local MYSLOT_COMPANION = _MySlot.Slot.SlotType.COMPANION
local MYSLOT_ITEM = _MySlot.Slot.SlotType.ITEM
local MYSLOT_MACRO = _MySlot.Slot.SlotType.MACRO
local MYSLOT_FLYOUT = _MySlot.Slot.SlotType.FLYOUT
local MYSLOT_EQUIPMENTSET = _MySlot.Slot.SlotType.EQUIPMENTSET
local MYSLOT_EMPTY = _MySlot.Slot.SlotType.EMPTY
local MYSLOT_SUMMONPET = _MySlot.Slot.SlotType.SUMMONPET
local MYSLOT_SUMMONMOUNT = _MySlot.Slot.SlotType.SUMMONMOUNT
local MYSLOT_NOTFOUND = "notfound"

MySlot.SLOT_TYPE = {
    ["spell"] = MYSLOT_SPELL,
    ["companion"] = MYSLOT_COMPANION,
    ["macro"]= MYSLOT_MACRO,
    ["item"]= MYSLOT_ITEM,
    ["flyout"] = MYSLOT_FLYOUT,
    ["petaction"] = MYSLOT_EMPTY,
    ["futurespell"] = MYSLOT_EMPTY,
    ["equipmentset"] = MYSLOT_EQUIPMENTSET,
    ["summonpet"] = MYSLOT_SUMMONPET,
    ["summonmount"] = MYSLOT_SUMMONMOUNT,
    [MYSLOT_NOTFOUND] = MYSLOT_EMPTY,
}
-- }}}

local MYSLOT_BIND_CUSTOM_FLAG = 0xFFFF

-- {{{ MergeTable
-- return item count merge into target
local function MergeTable(target, source)
    if source then
        assert(type(target) == 'table' and type(source) == 'table')
        for _,b in ipairs(source) do
            assert(b < 256)
            target[#target+1] = b
        end
        return #source
    else
        return 0
    end
end
-- }}}

-- fix unpack stackoverflow
local function StringToTable(s)
    if type(s) ~= 'string' then
        return {}
    end
    local r = {}
    for i = 1, string.len(s) do
        r[#r + 1] = string.byte(s, i)
    end
    return r
end

local function TableToString(s)
    if type(s) ~= 'table' then
        return ''
    end
    local t = {}
    for _,c in pairs(s) do
        t[#t + 1] = string.char(c)
    end
    return table.concat(t)
end

function MySlot:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000<|r|CFFFFD100Dewater|r|CFFFF0000>|r"..(msg or "nil"))
end

-- {{{ GetMacroInfo
function MySlot:GetMacroInfo(macroId)
    -- {macroId ,icon high 8, icon low 8 , namelen, ..., bodylen, ...}

    local name, iconTexture, body, isLocal = GetMacroInfo(macroId)

    if not name then
        return nil
    end

    iconTexture = gsub( strupper(iconTexture or "INV_Misc_QuestionMark") , "INTERFACE\\ICONS\\", "");

    local msg = _MySlot.Macro()
    msg.id = macroId
    msg.icon = iconTexture
    msg.name = name
    msg.body = body

    return msg
end
-- }}}

-- {{{ GetActionInfo
function MySlot:GetActionInfo(slotId)
    -- { slotId, slotType and high 16 ,high 8 , low 8, }
    local slotType, index = GetActionInfo(slotId)
    if MySlot.SLOT_TYPE[slotType] == MYSLOT_EQUIPMENTSET then
        -- i starts from 0 https://github.com/tg123/myslot/issues/10 weird blz
        for i = 0, C_EquipmentSet.GetNumEquipmentSets() do
            if C_EquipmentSet.GetEquipmentSetInfo(i) == index then
                index = i
                break
            end
        end
    elseif not MySlot.SLOT_TYPE[slotType] then
        if slotType then 
            self:Print(L["[WARN] Ignore unsupported Slot Type [ %s ] , contact %s please"]:format(slotType , MYSLOT_AUTHOR))
        end
        return nil
    elseif not index then
        return nil
    end

    local msg = _MySlot.Slot()
    msg.id = slotId
    msg.type = MySlot.SLOT_TYPE[slotType]
    if type(index) == 'string' then
        msg.strindex = index
        msg.index = 0
    else
        msg.index = index
    end
    return msg
end

-- }}}

-- {{{ GetBindingInfo
-- {{{ Serialzie Key
local function KeyToByte(key , command)
    -- {mod , key , command high 8, command low 8}
    if not key then
        return nil
    end

    local mod = nil
    local _, _, _mod, _key = string.find(key ,"(.+)-(.+)") 
    if _mod and _key then
        mod, key = _mod, _key
    end

    mod = mod or "NONE"

    if not MySlot.MOD_KEYS[mod] then
        MySlot:Print(L["[WARN] Ignore unsupported Key Binding [ %s ] , contact %s please"]:format(mod, MYSLOT_AUTHOR))
        return nil
    end

    local msg = _MySlot.Key()
    if MySlot.KEYS[key] then
        msg.key = MySlot.KEYS[key]
    else
        msg.key = MySlot.KEYS["KEYCODE"]
        msg.keycode = key
    end
    msg.mod = MySlot.MOD_KEYS[mod]

    return msg
end
-- }}}

function MySlot:GetBindingInfo(index)
    -- might more than 1
    local _command, _, key1, key2 = GetBinding(index)

    if not _command then
        return
    end

    local command = MySlot.BINDS[_command]

    local msg = _MySlot.Bind()

    if not command then
        msg.command = _command
        command = MYSLOT_BIND_CUSTOM_FLAG
    end

    msg.id = command

    msg.key1 = KeyToByte(key1)
    msg.key2 = KeyToByte(key2)

    if msg.key1 or msg.key2 then
        return msg
    else
        return nil
    end
end
-- }}}


function MySlot:Export(opt)
    -- ver nop nop nop crc32 crc32 crc32 crc32

    local msg = _MySlot.Charactor()

    msg.ver = MYSLOT_VER
    msg.name = UnitName("player")
    msg.realm = GetRealmName()
    _, _, raceID = UnitRace('player')
    msg.race = raceID
    _, _, classID = UnitClass('player')
    msg.class = classID
    msg.sex = UnitSex("player")
    msg.level = UnitLevel("player")

    msg.inventory = {}
    invtable = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19}
    for v, i in pairs(invtable) do
        itemLink = GetInventoryItemLink("player", v)
        if itemLink then
            local inv = _MySlot.Inventory()
            inv.id = i 
            inv.itemLink = itemLink
            msg.inventory[#msg.inventory + 1] = inv
        end 
    end

    msg.bag = {}
    for i = 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
        local invID = ContainerIDToInventoryID(i)
        baglink = GetInventoryItemLink("player", invID)
        if baglink then
            local b = _MySlot.Bag()
            b.id = i 
            b.baglink = baglink
            b.item = {}
            for j = 1,GetContainerNumSlots(i) do
                itemlink = GetContainerItemLink(i, j)
                if itemlink then
                    b.item[j] = itemlink
                else
                    b.item[j] = "empty"
                end
            end
            msg.bag[#msg.bag + 1] = b
        end
     end
    bagindex = {-2,-1,0}
    for v, i in pairs(bagindex) do 
        local b = _MySlot.Bag()
        b.id = i 
        b.item = {}
        for j = 1,GetContainerNumSlots(i) do
            itemlink = GetContainerItemLink(i, j)
            if itemlink then
                b.item[j] = itemlink
            else
                b.item[j] = "empty"
            end
        end
        msg.bag[#msg.bag + 1] = b
    end

    msg.macro = {}

    if not opt.ignoreMacro then
        for i = 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
            local m = self:GetMacroInfo(i)
            if m then
                msg.macro[#msg.macro + 1] = m
            end
        end
    end

    msg.slot = {}
    if opt.ignoreAction then
        -- dummy action, for older myslot to import and will do nothing
        for i = 1, MYSLOT_MAX_ACTIONBAR do
            local m = _MySlot.Slot()
            m.id = i
            m.type = MYSLOT_ITEM
            m.index = 0
            msg.slot[#msg.slot + 1] = m
        end
    else
        for i = 1, MYSLOT_MAX_ACTIONBAR do
            local m = self:GetActionInfo(i)
            if m then
                msg.slot[#msg.slot + 1] = m
            end
        end
    end

    msg.bind = {}
    if not opt.ignoreBinding then
        for i = 1, GetNumBindings() do
            local m = self:GetBindingInfo(i)
            if m then
                msg.bind[#msg.bind + 1] = m
            end
        end
    end

    local ct = msg:Serialize()
    local t = {MYSLOT_VER,86,04,22,0,0,0,0}
    MergeTable(t, StringToTable(ct))

    -- {{{ CRC32
    -- crc
    local crc = crc32.enc(t)
    t[5] = bit.rshift(crc , 24)
    t[6] = bit.band(bit.rshift(crc , 16), 255)
    t[7] = bit.band(bit.rshift(crc , 8) , 255)
    t[8] = bit.band(crc , 255)
    -- }}}
    
    -- {{{ OUTPUT
    local s = ""
    s = "@ --------------------" .. MYSLOT_LINE_SEP .. s
    s = "@ " .. L["Feedback"] .. "xjq314@gmail.com" .. MYSLOT_LINE_SEP .. s
    s = "@ " .. MYSLOT_LINE_SEP .. s
    s = "@ " .. LEVEL .. ":" ..UnitLevel("player") .. MYSLOT_LINE_SEP .. s
    -- s = "@ " .. SPECIALIZATION ..":" .. ( GetSpecialization() and select(2, GetSpecializationInfo(GetSpecialization())) or NONE_CAPS ) .. MYSLOT_LINE_SEP .. s
    -- s = "@ " .. TALENT .. ":" .. select(3,GetTalentTabInfo(1)) .. "/" .. select(3,GetTalentTabInfo(2)) .. "/" .. select(3,GetTalentTabInfo(3)) .. MYSLOT_LINE_SEP .. s
    s = "@ " .. CLASS .. ":" ..UnitClass("player") .. MYSLOT_LINE_SEP .. s
    s = "@ " .. RACE .. ":" ..UnitRace("player") .. MYSLOT_LINE_SEP .. s
    s = "@ " .. PLAYER ..":" ..UnitName("player") .. MYSLOT_LINE_SEP .. s
    s = "@ " .. "REALM" ..":" ..GetRealmName() .. MYSLOT_LINE_SEP .. s 
    s = "@ " .. L["Time"] .. ":" .. date() .. MYSLOT_LINE_SEP .. s
    s = "@ Wow (V" .. GetBuildInfo() .. ")" .. MYSLOT_LINE_SEP .. s
    s = "@ Dewater (V" .. DEWATER_VER .. ")" .. MYSLOT_LINE_SEP .. s

    local d = base64.enc(t)
    local LINE_LEN = 60
    for i = 1, d:len(), LINE_LEN do
        s = s .. d:sub(i, i + LINE_LEN - 1) .. MYSLOT_LINE_SEP
    end
    s = strtrim(s)
    s = s .. MYSLOT_LINE_SEP .. "@ --------------------"
    s = s .. MYSLOT_LINE_SEP .. "@ END OF DEWATER"

    return s
    -- }}}
end


local function UnifyCRLF(text)
    text = string.gsub(text, "\r", "")
    return strtrim(text)
end


