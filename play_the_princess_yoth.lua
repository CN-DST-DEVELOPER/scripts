local costumes = {}
local scripts = {}

local fn = require("play_commonfn")

costumes["PRINCESS"]=			{ body = "costume_princess_body",		head ="mask_princesshat",			name= STRINGS.CAST.PRINCESS}
costumes["KNIGHT"]=				{ body = "armor_yoth_knight",			head ="yoth_knighthat",				name= STRINGS.CAST.KNIGHT}

local starting_act = "PRINCESS_SOLILOQUY"
-----------------------------------------------------------------------------------------------------------------
    -- COSTUME PLAYS
	scripts["PRINCESS_SOLILOQUY"]= {
		cast = { "PRINCESS" },
		playbill = STRINGS.PLAYS.THEPRINCESS,
		skip_hound_spawn = true,
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["PRINCESS"] = 1,}},
            {actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 1, },
			{actionfn = fn.callbirds,		duration = 1.3, },

			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD1_1},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD2_2},
			{roles = {"BIRD1"},				duration = 3,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD1_3},
			{roles = {"BIRD1", "BIRD2"},	duration = 1.5,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD_4},

			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE1_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE2_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE3_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE4_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE5_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE6_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE7_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE8_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE9_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE10_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE11_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE12_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE13_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE14_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE15_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE16_PRINCESS},
			{roles = {"PRINCESS"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.LINE17_PRINCESS},

			{roles = {"BIRD1"},				duration = 1.5, 	line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD1_5},
			{roles = {"BIRD2"},				duration = 2.5,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD2_6},
			{roles = {"BIRD1", "BIRD2"},	duration = 2,		line = STRINGS.STAGEACTOR.PRINCESS_SOLILOQUY.BIRD_7},

			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },
			{actionfn = fn.exitbirds,		duration = 0.3, },
		}}

	scripts["KNIGHT_SOLILOQUY"]= {
		cast = { "KNIGHT" },
		-- playbill = STRINGS.PLAYS.THEPRINCESS,
		skip_hound_spawn = true,
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["KNIGHT"] = 1,}},
            {actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 1, },
			{actionfn = fn.callbirds,		duration = 1.3, },

			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD1_1},
			{roles = {"BIRD2"},				duration = 2.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD2_2},

			{roles = {"KNIGHT"},			duration = 1.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.LINE1_KNIGHT, anim="emote_shrug" },

			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD1_3},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD2_4},

			{roles = {"KNIGHT"},			duration = 1.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.LINE2_KNIGHT, anim="emote_shrug" },

			{roles = {"BIRD2"},				duration = 2.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD2_5},
			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD1_6},

			{roles = {"KNIGHT"},			nopause = true, 	anim="emoteXL_angry" },
			{roles = {"BIRD1", "BIRD2"},	duration = 2,		line = STRINGS.STAGEACTOR.KNIGHT_SOLILOQUY.BIRD_7},

			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },
			{actionfn = fn.exitbirds,		duration = 0.3, },
		}}
------------------------------------------------------------------------------------------------------------------

return {costumes=costumes, scripts=scripts, starting_act=starting_act}