--[[--------------------------------------------------------------------
	LibRealmInfo
	World of Warcraft library for obtaining information about realms.
	Copyright 2014-2018 Phanx <addons@phanx.net>
	Zlib license. Standalone distribution strongly discouraged.
	https://github.com/phanx-wow/LibRealmInfo
	https://wow.curseforge.com/projects/librealminfo
	https://www.wowinterface.com/downloads/info22987-LibRealmInfo
----------------------------------------------------------------------]]

local MAJOR, MINOR = "LibRealmInfo", 13
assert(LibStub, MAJOR.." requires LibStub")
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local standalone = (...) == MAJOR
local realmData, connectionData
local Unpack

local function debug(...)
	if standalone then
		print("|cffff7f7f["..MAJOR.."]|r", ...)
	end
end

local function shallowCopy(t)
	if not t then return end

	local n = {}
	for k, v in next, t do
		n[k] = v
	end
	return n
end

local function getNameForAPI(name)
	return name and (name:gsub("[%s%-]", "")) or nil
end

------------------------------------------------------------------------

local currentRegion

function lib:GetCurrentRegion()
	if currentRegion then
		return currentRegion
	end

	if Unpack then
		Unpack()
	end

	local guid = UnitGUID("player")
	if guid then
		local server = tonumber(strmatch(guid, "^Player%-(%d+)"))
		local realm = realmData[server]
		if realm then
			currentRegion = realm.region
			return currentRegion
		end
	end

	debug("GetCurrentRegion: could not identify region based on player GUID", guid)
end

------------------------------------------------------------------------

local validRegions = { US = true, EU = true, CN = true, KR = true, TW = true }

function lib:GetRealmInfo(name, region)
	debug("GetRealmInfo", name, region)
	local isString = type(name) == "string"
	if isString then
		name = strtrim(name)
	end
	if type(name) == "number" or isString and strmatch(name, "^%d+$") then
		return self:GetRealmInfoByID(name)
	end
	assert(isString and strlen(name) > 0, "Usage: GetRealmInfo(name[, region])")

	if not region or not validRegions[region] then
		region = self:GetCurrentRegion()
	end

	if Unpack then
		Unpack()
	end

	for id, realm in pairs(realmData) do
		if realm.region == region and (realm.nameForAPI == name or realm.name == name or realm.englishNameForAPI == name or realm.englishName == name) then
			return id, realm.name, realm.nameForAPI, realm.rules, realm.locale, nil, realm.region, realm.timezone, shallowCopy(realm.connections), realm.englishName, realm.englishNameForAPI
		end
	end

	debug("No info found for realm", name, "in region", region)
end

------------------------------------------------------------------------

function lib:GetRealmInfoByID(id)
	debug("GetRealmInfoByID", id)
	id = tonumber(id)
	assert(id, "Usage: GetRealmInfoByID(id)")

	if Unpack then
		Unpack()
	end

	local realm = realmData[id]
	if realm and realm.name then
		return realm.id, realm.name, realm.nameForAPI, realm.rules, realm.locale, nil, realm.region, realm.timezone, shallowCopy(realm.connections), realm.englishName, realm.englishNameForAPI
	end

	debug("No info found for realm ID", name)
end

------------------------------------------------------------------------

function lib:GetRealmInfoByGUID(guid)
	assert(type(guid) == "string", "Usage: GetRealmInfoByGUID(guid)")
	if not strmatch(guid, "^Player%-") then
		return debug("Unsupported GUID type", (strsplit("-", guid)))
	end
	local _, _, _, _, _, _, realm = GetPlayerInfoByGUID(guid)
	if realm == "" then
		realm = GetRealmName()
	end
	return self:GetRealmInfo(realm)
end

------------------------------------------------------------------------

function lib:GetRealmInfoByUnit(unit)
	assert(type(unit) == "string", "Usage: GetRealmInfoByUnit(unit)")
	local guid = UnitGUID(unit)
	if not guid then
		return debug("No GUID available for unit", unit)
	end
	return self:GetRealmInfoByGUID(guid)
end

------------------------------------------------------------------------

function Unpack()
	debug("Unpacking data...")

	for id, info in pairs(realmData) do
		-- Aegwynn,PvE,enUS,US,CST
		-- Nathrezim,PvE,deDE,EU
		-- Азурегос,PvE,ruRU,EU,Azuregos
		local name, rules, locale, region, timezone = strsplit(",", info)

		local englishName
		if region ~= "US" then
			englishName = timezone
			timezone = nil
		end

		realmData[id] = {
			id = id,
			name = name,
			nameForAPI = getNameForAPI(name),
			rules = string.upper(rules),
			locale = locale,
			region = region,
			timezone = timezone, -- only for realms in US region
			englishName = englishName, -- only for realms with non-Latin names
			englishNameForAPI = getNameForAPI(englishName), -- only for realms with non-Latin names
		}
	end

	for i = 1, #connectionData do
		local connectedRealms = { strsplit(",", connectionData[i]) }
		local connectionID = tonumber(table.remove(connectedRealms, 1))
		local region = table.remove(connectedRealms, 1)

		if not realmData[connectionID] then
			-- nameless server used to host connected realms
			table.insert(connectedRealms, connectionID)
			realmData[connectionID] = {
				region = region,
				connections = connectedRealms
			}
		end

		for j = 1, #connectedRealms do
			local realmID = tonumber(connectedRealms[j])
			connectedRealms[j] = realmID
			realmData[realmID].connections = connectedRealms
		end
	end

	-- Partial workaround for missing Chinese connected realm data:
	local autoCompleteRealms = GetAutoCompleteRealms()
	if #autoCompleteRealms > 0 then
		local autoCompleteIDs = {}
		for _, name in pairs(autoCompleteRealms) do
			for realmID, realm in pairs(realmData) do
				if realm.nameForAPI == name then
					table.insert(autoCompleteIDs, realmID)
					break
				end
			end
		end
		if #autoCompleteIDs == #autoCompleteRealms then
			for _, realmID in pairs(autoCompleteIDs) do
				local realm = realmData[realmID]
				if realm and not realm.connections then
					realm.connections = autoCompleteIDs
				end
			end
		else
			debug("Failed to match names from GetAutoCompleteRealms!")
		end
	end

	connectionData = nil
	Unpack = nil
	collectgarbage()

	debug("Done unpacking data.")
end

------------------------------------------------------------------------

realmData = {
[1]="Lightbringer,PvE,enUS,US,PST",
[2]="Cenarius,PvE,enUS,US,PST",
[3]="Uther,PvE,enUS,US,CST",
[4]="Kilrogg,PvE,enUS,US,PST",
[5]="Proudmoore,PvE,enUS,US,PST",
[6]="Hyjal,PvE,enUS,US,PST",
[7]="Frostwolf,PvE,enUS,US,PST",
[8]="Ner'zhul,PvE,enUS,US,CST",
[9]="Kil'jaeden,PvE,enUS,US,PST",
[10]="Blackrock,PvE,enUS,US,PST",
[11]="Tichondrius,PvE,enUS,US,PST",
[12]="Silver Hand,RP,enUS,US,PST",
[13]="Doomhammer,PvE,enUS,US,PST",
[14]="Icecrown,PvE,enUS,US,CST",
[15]="Deathwing,PvE,enUS,US,PST",
[16]="Kel'Thuzad,PvE,enUS,US,MST",
[47]="Eitrigg,PvE,enUS,US,CST",
[51]="Garona,PvE,enUS,US,CST",
[52]="Alleria,PvE,enUS,US,CST",
[53]="Hellscream,PvE,enUS,US,CST",
[54]="Blackhand,PvE,enUS,US,CST",
[55]="Whisperwind,PvE,enUS,US,CST",
[56]="Archimonde,PvE,enUS,US,CST",
[57]="Illidan,PvE,enUS,US,CST",
[58]="Stormreaver,PvE,enUS,US,CST",
[59]="Mal'Ganis,PvE,enUS,US,CST",
[60]="Stormrage,PvE,enUS,US,EST",
[61]="Zul'jin,PvE,enUS,US,EST",
[62]="Medivh,PvE,enUS,US,EST",
[63]="Durotan,PvE,enUS,US,EST",
[64]="Bloodhoof,PvE,enUS,US,EST",
[65]="Khadgar,PvE,enUS,US,CST",
[66]="Dalaran,PvE,enUS,US,EST",
[67]="Elune,PvE,enUS,US,EST",
[68]="Lothar,PvE,enUS,US,EST",
[69]="Arthas,PvE,enUS,US,EST",
[70]="Mannoroth,PvE,enUS,US,EST",
[71]="Warsong,PvE,enUS,US,EST",
[72]="Shattered Hand,PvE,enUS,US,PST",
[73]="Bleeding Hollow,PvE,enUS,US,EST",
[74]="Skullcrusher,PvE,enUS,US,EST",
[75]="Argent Dawn,RP,enUS,US,EST",
[76]="Sargeras,PvE,enUS,US,CST",
[77]="Azgalor,PvE,enUS,US,CST",
[78]="Magtheridon,PvE,enUS,US,EST",
[79]="Destromath,PvE,enUS,US,CST",
[80]="Gorgonnash,PvE,enUS,US,EST",
[81]="Dethecus,PvE,enUS,US,CST",
[82]="Spinebreaker,PvE,enUS,US,CST",
[83]="Bonechewer,PvE,enUS,US,CST",
[84]="Dragonmaw,PvE,enUS,US,PST",
[85]="Shadowsong,PvE,enUS,US,PST",
[86]="Silvermoon,PvE,enUS,US,PST",
[87]="Windrunner,PvE,enUS,US,PST",
[88]="Cenarion Circle,RP,enUS,US,PST",
[89]="Nathrezim,PvE,enUS,US,CST",
[90]="Terenas,PvE,enUS,US,MST",
[91]="Burning Blade,PvE,enUS,US,EST",
[92]="Gorefiend,PvE,enUS,US,CST",
[93]="Eredar,PvE,enUS,US,CST",
[94]="Shadowmoon,PvE,enUS,US,CST",
[95]="Lightning's Blade,PvE,enUS,US,EST",
[96]="Eonar,PvE,enUS,US,EST",
[97]="Gilneas,PvE,enUS,US,EST",
[98]="Kargath,PvE,enUS,US,EST",
[99]="Llane,PvE,enUS,US,EST",
[100]="Earthen Ring,RP,enUS,US,EST",
[101]="Laughing Skull,PvE,enUS,US,CST",
[102]="Burning Legion,PvE,enUS,US,CST",
[103]="Thunderlord,PvE,enUS,US,CST",
[104]="Malygos,PvE,enUS,US,CST",
[105]="Thunderhorn,PvE,enUS,US,CST",
[106]="Aggramar,PvE,enUS,US,CST",
[107]="Crushridge,PvE,enUS,US,CST",
[108]="Stonemaul,PvE,enUS,US,MST",
[109]="Daggerspine,PvE,enUS,US,CST",
[110]="Stormscale,PvE,enUS,US,EST",
[111]="Dunemaul,PvE,enUS,US,MST",
[112]="Boulderfist,PvE,enUS,US,MST",
[113]="Suramar,PvE,enUS,US,PST",
[114]="Dragonblight,PvE,enUS,US,PST",
[115]="Draenor,PvE,enUS,US,PST",
[116]="Uldum,PvE,enUS,US,PST",
[117]="Bronzebeard,PvE,enUS,US,PST",
[118]="Feathermoon,RP,enUS,US,PST",
[119]="Bloodscalp,PvE,enUS,US,MST",
[120]="Darkspear,PvE,enUS,US,MST",
[121]="Azjol-Nerub,PvE,enUS,US,MST",
[122]="Perenolde,PvE,enUS,US,MST",
[123]="Eldre'Thalas,PvE,enUS,US,EST",
[124]="Spirestone,PvE,enUS,US,EST",
[125]="Shadow Council,RP,enUS,US,MST",
[126]="Scarlet Crusade,RP,enUS,US,PST",
[127]="Firetree,PvE,enUS,US,EST",
[128]="Frostmane,PvE,enUS,US,CST",
[129]="Gurubashi,PvE,enUS,US,CST",
[130]="Smolderthorn,PvE,enUS,US,CST",
[131]="Skywall,PvE,enUS,US,PST",
[151]="Runetotem,PvE,enUS,US,CST",
[153]="Moonrunner,PvE,enUS,US,PST",
[154]="Detheroc,PvE,enUS,US,CST",
[155]="Kalecgos,PvE,enUS,US,PST",
[156]="Ursin,PvE,enUS,US,PST",
[157]="Dark Iron,PvE,enUS,US,PST",
[158]="Greymane,PvE,enUS,US,CST",
[159]="Wildhammer,PvE,enUS,US,CST",
[160]="Staghelm,PvE,enUS,US,CST",
[162]="Emerald Dream,RP,enUS,US,CST",
[163]="Maelstrom,RP,enUS,US,CST",
[164]="Twisting Nether,RP,enUS,US,CST",
[201]="불타는 군단,PvE,koKR,KR,Burning Legion",
[205]="아즈샤라,PvE,koKR,KR,Azshara",
[207]="달라란,PvE,koKR,KR,Dalaran",
[210]="듀로탄,PvE,koKR,KR,Durotan",
[211]="노르간논,PvE,koKR,KR,Norgannon",
[212]="가로나,PvE,koKR,KR,Garona",
[214]="윈드러너,PvE,koKR,KR,Windrunner",
[215]="굴단,PvE,koKR,KR,Gul'dan",
[258]="알렉스트라자,PvE,koKR,KR,Alexstrasza",
[264]="말퓨리온,PvE,koKR,KR,Malfurion",
[293]="헬스크림,PvE,koKR,KR,Hellscream",
[500]="Aggramar,PvE,enUS,EU",
[501]="Arathor,PvE,enUS,EU",
[502]="Aszune,PvE,enUS,EU",
[503]="Azjol-Nerub,PvE,enUS,EU",
[504]="Bloodhoof,PvE,enUS,EU",
[505]="Doomhammer,PvE,enUS,EU",
[506]="Draenor,PvE,enUS,EU",
[507]="Dragonblight,PvE,enUS,EU",
[508]="Emerald Dream,PvE,enUS,EU",
[509]="Garona,PvE,frFR,EU",
[510]="Vol'jin,PvE,frFR,EU",
[511]="Sunstrider,PvE,enUS,EU",
[512]="Arak-arahm,PvE,frFR,EU",
[513]="Twilight's Hammer,PvE,enUS,EU",
[515]="Zenedar,PvE,enUS,EU",
[516]="Forscherliga,RP,deDE,EU",
[517]="Medivh,PvE,frFR,EU",
[518]="Agamaggan,PvE,enUS,EU",
[519]="Al'Akir,PvE,enUS,EU",
[521]="Bladefist,PvE,enUS,EU",
[522]="Bloodscalp,PvE,enUS,EU",
[523]="Burning Blade,PvE,enUS,EU",
[524]="Burning Legion,PvE,enUS,EU",
[525]="Crushridge,PvE,enUS,EU",
[526]="Daggerspine,PvE,enUS,EU",
[527]="Deathwing,PvE,enUS,EU",
[528]="Dragonmaw,PvE,enUS,EU",
[529]="Dunemaul,PvE,enUS,EU",
[531]="Dethecus,PvE,deDE,EU",
[533]="Sinstralis,PvE,frFR,EU",
[535]="Durotan,PvE,deDE,EU",
[536]="Argent Dawn,RP,enUS,EU",
[537]="Kirin Tor,RP,frFR,EU",
[538]="Dalaran,PvE,frFR,EU",
[539]="Archimonde,PvE,frFR,EU",
[540]="Elune,PvE,frFR,EU",
[541]="Illidan,PvE,frFR,EU",
[542]="Hyjal,PvE,frFR,EU",
[543]="Kael'thas,PvE,frFR,EU",
[544]="Ner’zhul,PvE,frFR,EU,Ner'zhul",
[545]="Cho’gall,PvE,frFR,EU,Cho'gall",
[546]="Sargeras,PvE,frFR,EU",
[547]="Runetotem,PvE,enUS,EU",
[548]="Shadowsong,PvE,enUS,EU",
[549]="Silvermoon,PvE,enUS,EU",
[550]="Stormrage,PvE,enUS,EU",
[551]="Terenas,PvE,enUS,EU",
[552]="Thunderhorn,PvE,enUS,EU",
[553]="Turalyon,PvE,enUS,EU",
[554]="Ravencrest,PvE,enUS,EU",
[556]="Shattered Hand,PvE,enUS,EU",
[557]="Skullcrusher,PvE,enUS,EU",
[558]="Spinebreaker,PvE,enUS,EU",
[559]="Stormreaver,PvE,enUS,EU",
[560]="Stormscale,PvE,enUS,EU",
[561]="Earthen Ring,RP,enUS,EU",
[562]="Alexstrasza,PvE,deDE,EU",
[563]="Alleria,PvE,deDE,EU",
[564]="Antonidas,PvE,deDE,EU",
[565]="Baelgun,PvE,deDE,EU",
[566]="Blackhand,PvE,deDE,EU",
[567]="Gilneas,PvE,deDE,EU",
[568]="Kargath,PvE,deDE,EU",
[569]="Khaz'goroth,PvE,deDE,EU",
[570]="Lothar,PvE,deDE,EU",
[571]="Madmortem,PvE,deDE,EU",
[572]="Malfurion,PvE,deDE,EU",
[573]="Zuluhed,PvE,deDE,EU",
[574]="Nozdormu,PvE,deDE,EU",
[575]="Perenolde,PvE,deDE,EU",
[576]="Die Silberne Hand,RP,deDE,EU",
[577]="Aegwynn,PvE,deDE,EU",
[578]="Arthas,PvE,deDE,EU",
[579]="Azshara,PvE,deDE,EU",
[580]="Blackmoore,PvE,deDE,EU",
[581]="Blackrock,PvE,deDE,EU",
[582]="Destromath,PvE,deDE,EU",
[583]="Eredar,PvE,deDE,EU",
[584]="Frostmourne,PvE,deDE,EU",
[585]="Frostwolf,PvE,deDE,EU",
[586]="Gorgonnash,PvE,deDE,EU",
[587]="Gul'dan,PvE,deDE,EU",
[588]="Kel'Thuzad,PvE,deDE,EU",
[589]="Kil'jaeden,PvE,deDE,EU",
[590]="Mal'Ganis,PvE,deDE,EU",
[591]="Mannoroth,PvE,deDE,EU",
[592]="Zirkel des Cenarius,RP,deDE,EU",
[593]="Proudmoore,PvE,deDE,EU",
[594]="Nathrezim,PvE,deDE,EU",
[600]="Dun Morogh,PvE,deDE,EU",
[601]="Aman'thul,PvE,deDE,EU",
[602]="Sen'jin,PvE,deDE,EU",
[604]="Thrall,PvE,deDE,EU",
[605]="Theradras,PvE,deDE,EU",
[606]="Genjuros,PvE,enUS,EU",
[607]="Balnazzar,PvE,enUS,EU",
[608]="Anub'arak,PvE,deDE,EU",
[609]="Wrathbringer,PvE,deDE,EU",
[610]="Onyxia,PvE,deDE,EU",
[611]="Nera'thor,PvE,deDE,EU",
[612]="Nefarian,PvE,deDE,EU",
[613]="Kult der Verdammten,RP,deDE,EU",
[614]="Das Syndikat,RP,deDE,EU",
[615]="Terrordar,PvE,deDE,EU",
[616]="Krag'jin,PvE,deDE,EU",
[617]="Der Rat von Dalaran,RP,deDE,EU",
[618]="Nordrassil,PvE,enUS,EU",
[619]="Hellscream,PvE,enUS,EU",
[621]="Laughing Skull,PvE,enUS,EU",
[622]="Magtheridon,PvE,enUS,EU",
[623]="Quel'Thalas,PvE,enUS,EU",
[624]="Neptulon,PvE,enUS,EU",
[625]="Twisting Nether,PvE,enUS,EU",
[626]="Ragnaros,PvE,enUS,EU",
[627]="The Maelstrom,PvE,enUS,EU",
[628]="Sylvanas,PvE,enUS,EU",
[629]="Vashj,PvE,enUS,EU",
[630]="Bloodfeather,PvE,enUS,EU",
[631]="Darksorrow,PvE,enUS,EU",
[632]="Frostwhisper,PvE,enUS,EU",
[633]="Kor'gall,PvE,enUS,EU",
[635]="Defias Brotherhood,RP,enUS,EU",
[636]="The Venture Co,RP,enUS,EU",
[637]="Lightning's Blade,PvE,enUS,EU",
[638]="Haomarush,PvE,enUS,EU",
[639]="Xavius,PvE,enUS,EU",
[640]="Khaz Modan,PvE,frFR,EU",
[641]="Drek'Thar,PvE,frFR,EU",
[642]="Rashgarroth,PvE,frFR,EU",
[643]="Throk'Feroth,PvE,frFR,EU",
[644]="Conseil des Ombres,RP,frFR,EU",
[645]="Varimathras,PvE,frFR,EU",
[646]="Hakkar,PvE,enUS,EU",
[647]="Les Sentinelles,RP,frFR,EU",
[963]="暗影之月,PvE,zhTW,TW,Shadowmoon",
[964]="尖石,PvE,zhTW,TW,Spirestone",
[965]="雷鱗,PvE,zhTW,TW,Stormscale",
[966]="巨龍之喉,PvE,zhTW,TW,Dragonmaw",
[977]="冰霜之刺,PvE,zhTW,TW,Frostmane",
[978]="日落沼澤,PvE,zhTW,TW,Sundown Marsh",
[979]="地獄吼,PvE,zhTW,TW,Hellscream",
[980]="天空之牆,PvE,zhTW,TW,Skywall",
[982]="世界之樹,PvE,zhTW,TW,World Tree",
[985]="水晶之刺,PvE,zhTW,TW,Crystalpine Stinger",
[999]="狂熱之刃,PvE,zhTW,TW,Zealot Blade",
[1001]="冰風崗哨,PvE,zhTW,TW,Chillwind Point",
[1006]="米奈希爾,PvE,zhTW,TW,Menethil",
[1023]="屠魔山谷,PvE,zhTW,TW,Demon Fall Canyon",
[1033]="語風,PvE,zhTW,TW,Whisperwind",
[1037]="血之谷,PvE,zhTW,TW,Bleeding Hollow",
[1038]="亞雷戈斯,PvE,zhTW,TW,Arygos",
[1043]="夜空之歌,PvE,zhTW,TW,Nightsong",
[1046]="聖光之願,PvE,zhTW,TW,Light's Hope",
[1048]="銀翼要塞,PvE,zhTW,TW,Silverwing Hold",
[1049]="憤怒使者,PvE,zhTW,TW,Wrathbringer",
[1054]="阿薩斯,PvE,zhTW,TW,Arthas",
[1056]="眾星之子,PvE,zhTW,TW,Quel'dorei",
[1057]="寒冰皇冠,PvE,zhTW,TW,Icecrown",
[1067]="Cho'gall,PvE,enUS,US,CST",
[1068]="Gul'dan,PvE,enUS,US,EST",
[1069]="Kael'thas,PvE,enUS,US,CST",
[1070]="Alexstrasza,PvE,enUS,US,CST",
[1071]="Kirin Tor,RP,enUS,US,CST",
[1072]="Ravencrest,PvE,enUS,US,CST",
[1075]="Balnazzar,PvE,enUS,US,EST",
[1080]="Khadgar,PvE,enUS,EU",
[1081]="Bronzebeard,PvE,enUS,EU",
[1082]="Kul Tiras,PvE,enUS,EU",
[1083]="Chromaggus,PvE,enUS,EU",
[1084]="Dentarg,PvE,enUS,EU",
[1085]="Moonglade,RP,enUS,EU",
[1086]="La Croisade écarlate,RP,frFR,EU",
[1087]="Executus,PvE,enUS,EU",
[1088]="Trollbane,PvE,enUS,EU",
[1089]="Mazrigos,PvE,enUS,EU",
[1090]="Talnivarr,PvE,enUS,EU",
[1091]="Emeriss,PvE,enUS,EU",
[1092]="Drak'thul,PvE,enUS,EU",
[1093]="Ahn'Qiraj,PvE,enUS,EU",
[1096]="Scarshield Legion,RP,enUS,EU",
[1097]="Ysera,PvE,deDE,EU",
[1098]="Malygos,PvE,deDE,EU",
[1099]="Rexxar,PvE,deDE,EU",
[1104]="Anetheron,PvE,deDE,EU",
[1105]="Nazjatar,PvE,deDE,EU",
[1106]="Tichondrius,PvE,deDE,EU",
[1117]="Steamwheedle Cartel,RP,enUS,EU",
[1118]="Die ewige Wacht,RP,deDE,EU",
[1119]="Die Todeskrallen,RP,deDE,EU",
[1121]="Die Arguswacht,RP,deDE,EU",
[1122]="Uldaman,PvE,frFR,EU",
[1123]="Eitrigg,PvE,frFR,EU",
[1127]="Confrérie du Thorium,RP,frFR,EU",
[1128]="Azshara,PvE,enUS,US,CST",
[1129]="Agamaggan,PvE,enUS,US,CST",
[1130]="Lightninghoof,RP,enUS,US,CST",
[1131]="Nazjatar,PvE,enUS,US,EST",
[1132]="Malfurion,PvE,enUS,US,EST",
[1136]="Aegwynn,PvE,enUS,US,CST",
[1137]="Akama,PvE,enUS,US,PST",
[1138]="Chromaggus,PvE,enUS,US,CST",
[1139]="Draka,PvE,enUS,US,PST",
[1140]="Drak'thul,PvE,enUS,US,PST",
[1141]="Garithos,PvE,enUS,US,CST",
[1142]="Hakkar,PvE,enUS,US,CST",
[1143]="Khaz Modan,PvE,enUS,US,MST",
[1145]="Mug'thol,PvE,enUS,US,PST",
[1146]="Korgath,PvE,enUS,US,CST",
[1147]="Kul Tiras,PvE,enUS,US,CST",
[1148]="Malorne,PvE,enUS,US,EST",
[1151]="Rexxar,PvE,enUS,US,CST",
[1154]="Thorium Brotherhood,RP,enUS,US,PST",
[1165]="Arathor,PvE,enUS,US,PST",
[1173]="Madoran,PvE,enUS,US,CST",
[1175]="Trollbane,PvE,enUS,US,EST",
[1182]="Muradin,PvE,enUS,US,CST",
[1184]="Vek'nilash,PvE,enUS,US,CST",
[1185]="Sen'jin,PvE,enUS,US,CST",
[1190]="Baelgun,PvE,enUS,US,PST",
[1258]="Duskwood,PvE,enUS,US,EST",
[1259]="Zuluhed,PvE,enUS,US,PST",
[1260]="Steamwheedle Cartel,RP,enUS,US,CST",
[1262]="Norgannon,PvE,enUS,US,EST",
[1263]="Thrall,PvE,enUS,US,EST",
[1264]="Anetheron,PvE,enUS,US,EST",
[1265]="Turalyon,PvE,enUS,US,EST",
[1266]="Haomarush,PvE,enUS,US,CST",
[1267]="Scilla,PvE,enUS,US,PST",
[1268]="Ysondre,PvE,enUS,US,EST",
[1270]="Ysera,PvE,enUS,US,EST",
[1271]="Dentarg,PvE,enUS,US,CST",
[1276]="Andorhal,PvE,enUS,US,PST",
[1277]="Executus,PvE,enUS,US,PST",
[1278]="Dalvengyr,PvE,enUS,US,PST",
[1280]="Black Dragonflight,PvE,enUS,US,EST",
[1282]="Altar of Storms,PvE,enUS,US,EST",
[1283]="Uldaman,PvE,enUS,US,CST",
[1284]="Aerie Peak,PvE,enUS,US,PST",
[1285]="Onyxia,PvE,enUS,US,EST",
[1286]="Demon Soul,PvE,enUS,US,PST",
[1287]="Gnomeregan,PvE,enUS,US,PST",
[1288]="Anvilmar,PvE,enUS,US,CST",
[1289]="The Venture Co,RP,enUS,US,CST",
[1290]="Sentinels,RP,enUS,US,CST",
[1291]="Jaedenar,PvE,enUS,US,CST",
[1292]="Tanaris,PvE,enUS,US,CST",
[1293]="Alterac Mountains,PvE,enUS,US,EST",
[1294]="Undermine,PvE,enUS,US,CST",
[1295]="Lethon,PvE,enUS,US,CST",
[1296]="Blackwing Lair,PvE,enUS,US,CST",
[1297]="Arygos,PvE,enUS,US,EST",
[1298]="Vek'nilash,PvE,enUS,EU",
[1299]="Boulderfist,PvE,enUS,EU",
[1300]="Frostmane,PvE,enUS,EU",
[1301]="Outland,PvE,enUS,EU",
[1303]="Grim Batol,PvE,enUS,EU",
[1304]="Jaedenar,PvE,enUS,EU",
[1305]="Kazzak,PvE,enUS,EU",
[1306]="Tarren Mill,PvE,enUS,EU",
[1307]="Chamber of Aspects,PvE,enUS,EU",
[1308]="Ravenholdt,RP,enUS,EU",
[1309]="Pozzo dell'Eternità,PvE,itIT,EU",
[1310]="Eonar,PvE,enUS,EU",
[1311]="Kilrogg,PvE,enUS,EU",
[1312]="Aerie Peak,PvE,enUS,EU",
[1313]="Wildhammer,PvE,enUS,EU",
[1314]="Saurfang,PvE,enUS,EU",
[1316]="Nemesis,PvE,itIT,EU",
[1317]="Darkmoon Faire,RP,enUS,EU",
[1318]="Vek'lor,PvE,deDE,EU",
[1319]="Mug'thol,PvE,deDE,EU",
[1320]="Taerar,PvE,deDE,EU",
[1321]="Dalvengyr,PvE,deDE,EU",
[1322]="Rajaxx,PvE,deDE,EU",
[1323]="Ulduar,PvE,deDE,EU",
[1324]="Malorne,PvE,deDE,EU",
[1326]="Der Abyssische Rat,RP,deDE,EU",
[1327]="Der Mithrilorden,RP,deDE,EU",
[1328]="Tirion,PvE,deDE,EU",
[1330]="Ambossar,PvE,deDE,EU",
[1331]="Suramar,PvE,frFR,EU",
[1332]="Krasus,PvE,frFR,EU",
[1333]="Die Nachtwache,RP,deDE,EU",
[1334]="Arathi,PvE,frFR,EU",
[1335]="Ysondre,PvE,frFR,EU",
[1336]="Eldre'Thalas,PvE,frFR,EU",
[1337]="Culte de la Rive noire,RP,frFR,EU",
[1342]="Echo Isles,PvE,enUS,US,PST",
[1344]="The Forgotten Coast,PvE,enUS,US,EST",
[1345]="Fenris,PvE,enUS,US,PST",
[1346]="Anub'arak,PvE,enUS,US,CST",
[1347]="Blackwater Raiders,RP,enUS,US,MST",
[1348]="Vashj,PvE,enUS,US,PST",
[1349]="Korialstrasz,PvE,enUS,US,EST",
[1350]="Misha,PvE,enUS,US,CST",
[1351]="Darrowmere,PvE,enUS,US,PST",
[1352]="Ravenholdt,RP,enUS,US,CST",
[1353]="Bladefist,PvE,enUS,US,CST",
[1354]="Shu'halo,PvE,enUS,US,CST",
[1355]="Winterhoof,PvE,enUS,US,PST",
[1356]="Sisters of Elune,RP,enUS,US,PST",
[1357]="Maiev,PvE,enUS,US,MST",
[1358]="Rivendare,PvE,enUS,US,EST",
[1359]="Nordrassil,PvE,enUS,US,CST",
[1360]="Tortheldrin,PvE,enUS,US,CST",
[1361]="Cairne,PvE,enUS,US,MST",
[1362]="Drak'Tharon,PvE,enUS,US,EST",
[1363]="Antonidas,PvE,enUS,US,PST",
[1364]="Shandris,PvE,enUS,US,PST",
[1365]="Moon Guard,RP,enUS,US,CST",
[1367]="Nazgrel,PvE,enUS,US,CST",
[1368]="Hydraxis,PvE,enUS,US,MST",
[1369]="Wyrmrest Accord,RP,enUS,US,PST",
[1370]="Farstriders,RP,enUS,US,PST",
[1371]="Borean Tundra,PvE,enUS,US,PST",
[1372]="Quel'dorei,PvE,enUS,US,CST",
[1373]="Garrosh,PvE,enUS,US,EST",
[1374]="Mok'Nathal,PvE,enUS,US,PST",
[1375]="Nesingwary,PvE,enUS,US,CST",
[1377]="Drenden,PvE,enUS,US,PST",
[1378]="Dun Modr,PvE,esES,EU",
[1379]="Zul'jin,PvE,esES,EU",
[1380]="Uldum,PvE,esES,EU",
[1381]="C'Thun,PvE,esES,EU",
[1382]="Sanguino,PvE,esES,EU",
[1383]="Shen'dralar,PvE,esES,EU",
[1384]="Tyrande,PvE,esES,EU",
[1385]="Exodar,PvE,esES,EU",
[1386]="Minahonda,PvE,esES,EU",
[1387]="Los Errantes,PvE,esES,EU",
[1388]="Lightbringer,PvE,enUS,EU",
[1389]="Darkspear,PvE,enUS,EU",
[1391]="Alonsus,PvE,enUS,EU",
[1392]="Burning Steppes,PvE,enUS,EU",
[1393]="Bronze Dragonflight,PvE,enUS,EU",
[1394]="Anachronos,PvE,enUS,EU",
[1395]="Colinas Pardas,PvE,esES,EU",
[1400]="Un'Goro,PvE,deDE,EU",
[1401]="Garrosh,PvE,deDE,EU",
[1404]="Area 52,PvE,deDE,EU",
[1405]="Todeswache,RP,deDE,EU",
[1406]="Arygos,PvE,deDE,EU",
[1407]="Teldrassil,PvE,deDE,EU",
[1408]="Norgannon,PvE,deDE,EU",
[1409]="Lordaeron,PvE,deDE,EU",
[1413]="Aggra (Português),PvE,ptBR,EU",
[1415]="Terokkar,PvE,enUS,EU",
[1416]="Blade's Edge,PvE,enUS,EU",
[1417]="Azuremyst,PvE,enUS,EU",
[1425]="Drakkari,PvE,esMX,US,CST",
[1427]="Ragnaros,PvE,esMX,US,CST",
[1428]="Quel'Thalas,PvE,esMX,US,CST",
[1549]="Azuremyst,PvE,enUS,US,CST",
[1555]="Auchindoun,PvE,enUS,US,CST",
[1556]="Coilfang,PvE,enUS,US,PST",
[1557]="Shattered Halls,PvE,enUS,US,PST",
[1558]="Blood Furnace,PvE,enUS,US,EST",
[1559]="The Underbog,PvE,enUS,US,CST",
[1563]="Terokkar,PvE,enUS,US,CST",
[1564]="Blade's Edge,PvE,enUS,US,CST",
[1565]="Exodar,PvE,enUS,US,EST",
[1566]="Area 52,PvE,enUS,US,EST",
[1567]="Velen,PvE,enUS,US,EST",
[1570]="The Scryers,RP,enUS,US,EST",
[1572]="Zangarmarsh,PvE,enUS,US,CST",
[1576]="Fizzcrank,PvE,enUS,US,CST",
[1578]="Ghostlands,PvE,enUS,US,CST",
[1579]="Grizzly Hills,PvE,enUS,US,EST",
[1581]="Galakrond,PvE,enUS,US,CST",
[1582]="Dawnbringer,PvE,enUS,US,CST",
[1587]="Hellfire,PvE,enUS,EU",
[1588]="Ghostlands,PvE,enUS,EU",
[1589]="Nagrand,PvE,enUS,EU",
[1595]="The Sha'tar,RP,enUS,EU",
[1596]="Karazhan,PvE,enUS,EU",
[1597]="Auchindoun,PvE,enUS,EU",
[1598]="Shattered Halls,PvE,enUS,EU",
[1602]="Гордунни,PvE,ruRU,EU,Gordunni",
[1603]="Король-лич,PvE,ruRU,EU,Lich King",
[1604]="Свежеватель Душ,PvE,ruRU,EU,Soulflayer",
[1605]="Страж Смерти,PvE,ruRU,EU,Deathguard",
[1606]="Sporeggar,RP,enUS,EU",
[1607]="Nethersturm,PvE,deDE,EU",
[1608]="Shattrath,PvE,deDE,EU",
[1609]="Подземье,PvE,ruRU,EU,Deepholm",
[1610]="Седогрив,PvE,ruRU,EU,Greymane",
[1611]="Festung der Stürme,PvE,deDE,EU",
[1612]="Echsenkessel,PvE,deDE,EU",
[1613]="Blutkessel,PvE,deDE,EU",
[1614]="Галакронд,PvE,ruRU,EU,Galakrond",
[1615]="Ревущий фьорд,PvE,ruRU,EU,Howling Fjord",
[1616]="Разувий,PvE,ruRU,EU,Razuvious",
[1617]="Ткач Смерти,PvE,ruRU,EU,Deathweaver",
[1618]="Die Aldor,RP,deDE,EU",
[1619]="Das Konsortium,RP,deDE,EU",
[1620]="Chants éternels,PvE,frFR,EU",
[1621]="Marécage de Zangar,PvE,frFR,EU",
[1622]="Temple noir,PvE,frFR,EU",
[1623]="Дракономор,PvE,ruRU,EU,Fordragon",
[1624]="Naxxramas,PvE,frFR,EU",
[1625]="Борейская тундра,PvE,ruRU,EU,Borean Tundra",
[1626]="Les Clairvoyants,RP,frFR,EU",
[1922]="Азурегос,PvE,ruRU,EU,Azuregos",
[1923]="Ясеневый лес,PvE,ruRU,EU,Ashenvale",
[1924]="Пиратская Бухта,PvE,ruRU,EU,Booty Bay",
[1925]="Вечная Песня,PvE,ruRU,EU,Eversong",
[1926]="Термоштепсель,PvE,ruRU,EU,Thermaplugg",
[1927]="Гром,PvE,ruRU,EU,Grom",
[1928]="Голдринн,PvE,ruRU,EU,Goldrinn",
[1929]="Черный Шрам,PvE,ruRU,EU,Blackscar",
[2075]="雲蛟衛,PvE,zhTW,TW,Order of the Cloud Serpent",
[2079]="와일드해머,PvE,koKR,KR,Wildhammer",
[2106]="렉사르,PvE,koKR,KR,Rexxar",
[2107]="하이잘,PvE,koKR,KR,Hyjal",
[2108]="데스윙,PvE,koKR,KR,Deathwing",
[2110]="세나리우스,PvE,koKR,KR,Cenarius",
[2111]="스톰레이지,PvE,koKR,KR,Stormrage",
[2116]="줄진,PvE,koKR,KR,Zul'jin",
[3207]="Goldrinn,PvE,ptBR,US,undefined",
[3208]="Nemesis,PvE,ptBR,US,undefined",
[3209]="Azralon,PvE,ptBR,US,undefined",
[3210]="Tol Barad,PvE,ptBR,US,undefined",
[3234]="Gallywix,PvE,ptBR,US,undefined",
[3721]="Caelestrasz,PvE,enUS,US,AEST",
[3722]="Aman'Thul,PvE,enUS,US,AEST",
[3723]="Barthilas,PvE,enUS,US,AEST",
[3724]="Thaurissan,PvE,enUS,US,AEST",
[3725]="Frostmourne,PvE,enUS,US,AEST",
[3726]="Khaz'goroth,PvE,enUS,US,AEST",
[3733]="Dreadmaul,PvE,enUS,US,AEST",
[3734]="Nagrand,PvE,enUS,US,AEST",
[3735]="Dath'Remar,PvE,enUS,US,AEST",
[3736]="Jubei'Thos,PvE,enUS,US,AEST",
[3737]="Gundrak,PvE,enUS,US,AEST",
[3738]="Saurfang,PvE,enUS,US,AEST",
}

connectionData = {
"4,US,4,1355",
"5,US,5",
"7,US,7,1348",
"9,US,9",
"10,US,10",
"11,US,11",
"12,US,12,1154,1370",
"47,US,47,1354",
"51,US,51",
"52,US,52,65",
"53,US,53,1572",
"54,US,54,1581",
"55,US,55,1271",
"57,US,57",
"58,US,58",
"60,US,60",
"61,US,61",
"62,US,62,1565",
"63,US,63,1270",
"64,US,64,1258",
"67,US,67,97",
"68,US,68,1579",
"69,US,69",
"70,US,70,1131,1558",
"71,US,71,80,1075,1293,1344",
"73,US,73",
"74,US,74,1068,1280",
"75,US,75,1570",
"76,US,76",
"77,US,77,79,103,1128",
"78,US,78,1264,1268,1282",
"84,US,84,1137,1145",
"85,US,85,1371",
"86,US,86,1374",
"87,US,87,1351",
"90,US,90,1368",
"91,US,91,95,1285",
"96,US,96,1567",
"98,US,98,1262",
"99,US,99,1297",
"100,US,100",
"101,US,101,1067,1555",
"104,US,104,14",
"105,US,105,1564",
"106,US,106,1576",
"113,US,113,1139",
"114,US,114,1345",
"115,US,115,1342",
"116,US,116,1363",
"117,US,117,1364",
"118,US,118,126",
"119,US,119,108,111,112,1357",
"120,US,120",
"121,US,121,1143",
"122,US,122,1361",
"123,US,123,1349",
"125,US,125,1347",
"127,US,127,110,124,1148,1358,1362",
"128,US,128,8,1360",
"131,US,131,1140",
"151,US,151,3",
"153,US,153,1287",
"154,US,154,81,94,1266,1295,1296",
"155,US,155,15,1277,1557",
"156,US,156,1259,1267,1276",
"157,US,157,72,1278,1286,1556",
"158,US,158,1292",
"159,US,159,82,92,93",
"160,US,160,1549",
"162,US,162",
"163,US,163,1130,1289",
"164,US,164,1352",
"201,KR,201,2111",
"205,KR,205",
"210,KR,210",
"214,KR,214,2079,2106",
"293,KR,293",
"509,EU,509,544,546",
"510,EU,510,1620",
"512,EU,512,543,642,643",
"516,EU,516,1333",
"531,EU,531,605,610,615,1319",
"535,EU,535,1328",
"567,EU,567,1323",
"568,EU,568,1330",
"570,EU,570,565",
"578,EU,578,588,609,1318,1613",
"579,EU,579,616",
"580,EU,580",
"581,EU,581",
"604,EU,604",
"612,EU,612,582,586,591,611",
"633,EU,633,556,630,1087,1392",
"639,EU,639,519,557",
"963,TW,963,1033,1056",
"964,TW,964,1001,1057",
"966,TW,966,965,1043",
"977,TW,977,1006,1037",
"978,TW,978,1023,1048",
"980,TW,980,1046",
"985,TW,985,1049",
"999,TW,999,979,1054",
"1069,US,1069,1578",
"1070,US,1070,1563",
"1071,US,1071,1260,1290",
"1072,US,1072,1283",
"1080,EU,1080,504",
"1081,EU,1081,1312",
"1082,EU,1082,1391,1394",
"1084,EU,1084,1306",
"1085,EU,1085,1117,1595",
"1086,EU,1086,644,1337",
"1091,EU,1091,513,518,522,525,646",
"1092,EU,1092,523",
"1096,EU,1096,635,636,1308,1606",
"1097,EU,1097,1324",
"1098,EU,1098,572",
"1099,EU,1099,563",
"1104,EU,1104,587,589,594,1322,1611",
"1105,EU,1105,573,584,608,1321",
"1106,EU,1106,1409",
"1118,EU,1118,576",
"1121,EU,1121,613,614,1119,1326,1619",
"1122,EU,1122,641",
"1123,EU,1123,1332",
"1127,EU,1127,647,1626",
"1129,US,1129,56,102,1291,1559",
"1136,US,1136,83,109,129,1142",
"1138,US,1138,89,107,130,1141,1346",
"1146,US,1146",
"1147,US,1147,1353",
"1151,US,1151,1350",
"1165,US,1165,1377",
"1168,US,2",
"1169,US,88,1356",
"1171,US,1369",
"1173,US,1173,1582",
"1174,US,1288,1294",
"1175,US,1175,1132",
"1182,US,1182,1359",
"1184,US,1184,1367,1375",
"1185,US,1185,1372",
"1190,US,1190,13",
"1300,EU,1300",
"1301,EU,1301",
"1302,EU,539",
"1303,EU,1303,1413",
"1305,EU,1305",
"1307,EU,1307",
"1309,EU,1309",
"1311,EU,1311,547,1589",
"1313,EU,1313,552",
"1315,EU,540,645",
"1316,EU,1316",
"1317,EU,1317,561",
"1325,EU,500,619",
"1327,EU,1327,617",
"1329,EU,554",
"1331,EU,1331,517",
"1335,EU,1335",
"1336,EU,1336,533,545",
"1378,EU,1378",
"1379,EU,1379,1380,1382,1383",
"1381,EU,1381",
"1384,EU,1384,1387,1395",
"1385,EU,1385,1386",
"1388,EU,1388,1089",
"1389,EU,1389,1314,1415",
"1390,EU,542",
"1393,EU,1393,618",
"1396,EU,503,623",
"1400,EU,1400,602,1404",
"1401,EU,1401,574,1608",
"1402,EU,505,553",
"1403,EU,506",
"1405,EU,1405,592",
"1406,EU,1406,569",
"1407,EU,1407,575",
"1408,EU,1408,600",
"1416,EU,1416,1298,1310",
"1417,EU,1417,550",
"1425,US,1425",
"1426,US,1284",
"1427,US,1427",
"1428,US,1428",
"1587,EU,1587,501",
"1588,EU,1588,507",
"1596,EU,1596,527,627,637",
"1597,EU,1597,529,1304",
"1598,EU,1598,511,526,607,621,1083,1088,1090,1093,1299",
"1602,EU,1602",
"1603,EU,1603,1610",
"1604,EU,1604",
"1605,EU,1605",
"1607,EU,1607,562",
"1609,EU,1609,1616",
"1612,EU,1612,590,1320",
"1614,EU,1614",
"1615,EU,1615",
"1618,EU,1618",
"1621,EU,1621,538",
"1623,EU,1623",
"1624,EU,1624,541,1334,1622",
"1625,EU,1625",
"1922,EU,1922",
"1923,EU,1923",
"1924,EU,1924,1617",
"1925,EU,1925",
"1927,EU,1927,1926",
"1928,EU,1928",
"1929,EU,1929",
"2073,EU,560",
"2074,EU,508,551",
"2107,KR,2107",
"2108,KR,2108,258",
"2110,KR,2110,207,211,264",
"2116,KR,2116,212,215",
"3207,US,3207",
"3208,US,3208,3210",
"3209,US,3209",
"3234,US,3234",
"3391,EU,549",
"3656,EU,528,558,559,629,638",
"3657,EU,515,521,632",
"3660,EU,606,624,631",
"3661,US,6",
"3663,TW,982,1038,2075",
"3666,EU,502,548",
"3674,EU,625",
"3675,US,1365",
"3676,US,1566",
"3677,US,1373",
"3678,US,1263",
"3679,EU,577",
"3680,EU,601",
"3681,EU,622",
"3682,EU,626",
"3683,US,66",
"3684,US,59",
"3685,US,1265",
"3686,EU,564",
"3687,EU,628",
"3690,EU,640",
"3691,EU,566",
"3692,EU,583",
"3693,US,16",
"3694,US,1",
"3696,EU,571,593",
"3702,EU,536",
"3703,EU,585",
"3713,EU,524",
"3714,EU,537",
"3721,US,3721,3734",
"3722,US,3722",
"3723,US,3723",
"3724,US,3724,3733",
"3725,US,3725",
"3726,US,3726,3735",
"3728,US,3736,3737",
"3729,US,3738",
}

------------------------------------------------------------------------

if standalone then
	LRI_RealmData = realmData
	LRI_ConnectionData = connectionData
end
