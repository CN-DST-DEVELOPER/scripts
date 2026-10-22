local VERSIONING = {
    GAMEIDS = {},
    MODIDS = {},
    NAMES = {},
}
do -- Scope block.
    local uniquegameids = {}
    local uniquemodids = {}
    local uniquenames = {}
    local function AddVersion(gameid, modid, name)
        if not uniquegameids[gameid] then
            table.insert(VERSIONING.GAMEIDS, gameid)
            uniquegameids[modid] = true
        end
        if not uniquemodids[modid] then
            table.insert(VERSIONING.MODIDS, modid)
            uniquemodids[modid] = true
        end

        if not uniquenames[name] then
            table.insert(VERSIONING.NAMES, name)
            uniquenames[name] = true
        end
    end
    AddVersion("01", "R01_ANR_PART1", "n/a")
    AddVersion("02", "R02_ANR_WARTSANDALL", "n/a")
    AddVersion("03", "R03_ANR_ARTSANDCRAFTS", "n/a")
    AddVersion("04", "R04_ANR_CUTEFUZZYANIMALS", "n/a")
    AddVersion("05", "R05_ANR_HERDMENTALITY", "n/a")
    AddVersion("06", "R06_ANR_AGAINSTTHEGRAIN", "n/a")
    AddVersion("07", "R07_ANR_HEARTOFTHERUINS", "n/a")
    AddVersion("08", "R08_ROT_TURNOFTIDES", "n/a")
    AddVersion("09", "R09_ROT_SALTYDOG", "n/a")
    AddVersion("10", "R09_ROT_HOOKLINEANDINKER", "n/a")
    AddVersion("11", "R11_ROT_SHESELLSSEASHELLS", "n/a")
    AddVersion("12", "R12_ROT_TROUBLEDWATERS", "n/a")
    AddVersion("13", "R13_ROT_FORGOTTENKNOWLEDGE", "n/a")
    AddVersion("14", "R14_FARMING_REAPWHATYOUSOW", "n/a")
    AddVersion("15", "R15_QOL_WORLDSETTINGS", "n/a")
    AddVersion("16", "R16_ROT_MOONSTORMS", "n/a")
    AddVersion("17", "R17_WATERLOGGED", "n/a")
    AddVersion("18", "R18_QOL_SERVERPAUSING", "n/a")
    AddVersion("19", "R19_REFRESH_WOLFGANG", "n/a")
    AddVersion("20", "R20_QOL_CRAFTING4LIFE", "n/a")
    AddVersion("21", "R21_REFRESH_WX78", "n/a")
    AddVersion("22", "R22_PIRATEMONKEYS", "n/a")
    AddVersion("23", "R23_REFRESH_WICKERBOTTOM", "n/a")
    AddVersion("24", "R24_STS_ALITTLEDRAMA", "n/a")
    AddVersion("25", "R25_REFRESH_WAXWELL", "n/a")
    AddVersion("26", "R26_LOBBY_NETWORKQOL", "n/a")
    AddVersion("27", "R27_REFRESH_WILSON", "n/a")
    AddVersion("28", "R28_LUNAR_RIFT", "n/a")
    AddVersion("29", "R29_SHADOW_RIFT", "n/a")
    AddVersion("30", "R30_ST_WOODWOLFWORM", "n/a")
    AddVersion("31", "R31_LUNAR_MUTANTS", "n/a")
    AddVersion("32", "R32_ST_WATHGRITHRWILLOW", "n/a")
    AddVersion("33", "R33_QOL_SPRINGCLEANING", "n/a")
    AddVersion("34", "R34_OCEANQOL_WINONAWURT", "n/a")
    AddVersion("35", "R35_SANITYTROUBLES", "n/a")
    AddVersion("36", "R36_ST_WENDWALTWORT", "n/a")
    AddVersion("37", "R37_LUNAR_CAGE", "n/a")
    AddVersion("38", "R38_ELECTROCUTE", "n/a")
    AddVersion("39", "R39_WHIRL_VAULT", "n/a")
    AddVersion("40", "R40_PEARLMAS", "n/a")
    AddVersion("41", "R41_ST_WX78", "n/a")
    AddVersion("42", "R42_HEATED_VAULT", "n/a")
    -- NOTES(JBK): This is how a new version is added for an update that did not have a beta.
    -- Use the prior mod release id and version but use a dot syntax with an incrementing value that starts at 1 with no zero padding until the next beta.
    --AddVersion("42.1", "R42_HEATED_VAULT", "n/a")
    AddVersion("43", "R43_SHADOWYDEPTHS", "Cursed Confrontation Part 2")
end

local MAJOR_VERSION = VERSIONING.GAMEIDS[#VERSIONING.GAMEIDS]
VERSIONING.CURRENTVERSION = string.format("%s_%d", MAJOR_VERSION, require("versioning_skins").VERSION)
VERSIONING.UPDATENAME = VERSIONING.NAMES[#VERSIONING.NAMES]
return VERSIONING
