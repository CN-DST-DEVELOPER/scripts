local costumes = {}
local scripts = {}

local fn = require("play_commonfn")

costumes["ARTIFICER"]	= {	head ="mask_ancient_masonhat",			name= STRINGS.CAST.ARTIFICER}
costumes["VISIONIST"]	= {	head ="mask_ancient_architecthat",		name= STRINGS.CAST.VISIONIST }
costumes["ELYTRA"]		= {	head ="mask_ancient_handmaidhat",		name= STRINGS.CAST.ELYTRA }


local starting_act = "THEVAULT"
-----------------------------------------------------------------------------------------------------------------
    -- COSTUME PLAYS
	scripts["ARTIFICER_SOLILOQUY"]= {
		cast = { "ARTIFICER" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["ARTIFICER"] = 1,}},
         	{actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 2, },
            {actionfn = fn.callbirds,		duration = 1.3, },

            {roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[1]},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[2]},
			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[3]},
			{roles = {"BIRD2"},				duration = 1.5,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[4]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[5]},

			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[6]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[7]},
			{roles = {"ARTIFICER"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[8]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[9]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[10]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[11]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[12]},
			{roles = {"ARTIFICER"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[13]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[14]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[15]},
			{roles = {"ARTIFICER"},		duration = 3, 	line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[16]},

            {roles = {"BIRD1"},				duration = 2,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[17]},
			{roles = {"BIRD2"},				duration = 1,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[18]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.ARTIFICER_SOLILOQUY[19]},

			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },
            {actionfn = fn.exitbirds,		duration = 0.3, },
        }
	}


	scripts["VISIONIST_SOLILOQUY"]= {
		cast = { "VISIONIST" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["VISIONIST"] = 1,}},
         	{actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 2, },
            {actionfn = fn.callbirds,		duration = 1.3, },

            {roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[1]},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[2]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[3]},

			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[4]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[5]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[6]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[7]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[8]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[9]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[10]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[11]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[12]},
			{roles = {"VISIONIST"},		duration = 3, 	line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[13]},

            {roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[14]},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[15]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.VISIONIST_SOLILOQUY[16]},

			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },
            {actionfn = fn.exitbirds,		duration = 0.3, },
		}
	}

	scripts["ELYTRA_SOLILOQUY"]= {
		cast = { "ELYTRA" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["ELYTRA"] = 1,}},
            {actionfn = fn.marionetteon,    duration = 1, },
            {actionfn = fn.callbirds,		duration = 1.3, },

            {roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[1]},
			{roles = {"BIRD2"},				duration = 2.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[2]},
			{roles = {"BIRD1"},				duration = 1.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[3]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[4]},

			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[5]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[6]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[7]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[8]},
			{roles = {"ELYTRA"},		duration = 2, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[9], do_idle_for_line = true},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[10]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[11]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[12]},
			{roles = {"ELYTRA"},		duration = 3, 	line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[13]},

            {roles = {"BIRD1"},				duration = 2.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[14]},
			{roles = {"BIRD2"},				duration = 2.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[15]},
			{roles = {"BIRD1", "BIRD2"},    duration = 1.5,		line = STRINGS.STAGEACTOR.ELYTRA_SOLILOQUY[16]},

            {actionfn = fn.marionetteoff,   duration = 0.1, },
            {actionfn = fn.exitbirds,		duration = 0.3, },
		}
	}


------------------------------------------------------------------------------------------------------------------
local MARIONETTE_TIME = 1.1

	-- THE PLAY
	scripts["THEVAULT"]= {
		cast = { "ARTIFICER","VISIONIST","ELYTRA" },
		playbill = STRINGS.PLAYS.THEVAULT,
		next = "THEVAULT",
		lines = {
			{actionfn = fn.findpositions,	duration = 1,		positions={["ARTIFICER"] = 10,["VISIONIST"] = 9,["ELYTRA"] = 7,}},

			{actionfn = fn.stageon,			duration = 1.5, },
			{actionfn = fn.stinger,			duration = 0.01,	sound = "stageplay_set/statue_lyre/stinger_intro_act1" },
			{actionfn = fn.marionetteon,	duration = 0.2,		time = MARIONETTE_TIME},
			{actionfn = fn.actorsbow,		duration = 1, },

			{actionfn = fn.callbirds,		duration = 2, },

			{actionfn = fn.startbgmusic,	duration = 0.2,		musictype = "confession"}, --bgm_mood: dontstarve/music/music_cavepuzzle
            
            {roles = {"BIRD1"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD1_1},
			{roles = {"BIRD2"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD2_2},
			{roles = {"BIRD1"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD1_3},

			--

			{roles = {"ARTIFICER"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE1_ARTIFICER },
			{roles = {"ARTIFICER"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE2_ARTIFICER },
			{roles = {"ARTIFICER"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE3_ARTIFICER },
			{roles = {"ARTIFICER"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE4_ARTIFICER, anim = "emoteXL_angry" },

			{roles = {"VISIONIST"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE5_VISIONIST },
			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE6_VISIONIST, anim = "emote_swoon" },
			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE7_VISIONIST, anim = "emoteXL_kiss" },

			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE8_ELYTRA },
			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE9_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE10_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE11_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE12_ELYTRA },

			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE13_VISIONIST },
			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE14_VISIONIST },
			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE15_VISIONIST },
			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE16_VISIONIST, anim = "emote_swoon" },

			{roles = {"ARTIFICER"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE17_ARTIFICER, anim = "emoteXL_facepalm" },

			{roles = {"ELYTRA"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE18_ELYTRA, do_idle_for_line = true },

			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE19_VISIONIST, anim = "emote_shrug" },

			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE20_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE21_ELYTRA, anim = {"bow_pre","bow_pst"} },
			{roles = {"ELYTRA"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE22_ELYTRA, anim = "emoteXL_happycheer" },

			{roles = {"VISIONIST"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE23_VISIONIST, anim = "emoteXL_happycheer" },

			{roles = {"ARTIFICER"},			duration = 2,		line = STRINGS.STAGEACTOR.THEVAULT.LINE24_ARTIFICER, anim = "emote_impatient" },

			{roles = {"ELYTRA"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE25_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE26_ELYTRA },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE27_ELYTRA, anim={"bow_pre","bow_pst"} },

			{roles = {"VISIONIST"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE28_VISIONIST },
			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE29_VISIONIST },
			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE30_VISIONIST, anim = "emote_swoon" },

			{roles = {"ARTIFICER"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE31_ARTIFICER, anim = "emoteXL_facepalm" },

			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE32_ELYTRA },
			{roles = {"ELYTRA"},			duration = 1.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE33_ELYTRA },

			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE34_ELYTRA, anim={"emote_pre_toast_chalice", "emote_loop_toast_chalice"}, endidleanim = "emote_loop_toast_chalice", animtype = "loop" },
			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE35_ELYTRA, anim = {"emote_loop_toast_chalice", "emote_pst_toast_chalice"}, check_current_anim = true, },

			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE36_VISIONIST },
			{roles = {"VISIONIST"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE37_VISIONIST, anim={"emote_pre_toast_chalice", "emote_loop_toast_chalice"}, endidleanim = "emote_loop_toast_chalice", animtype = "loop" },

			{roles = {"VISIONIST"},			duration = 0.1},
			{actionfn = fn.override_with_chalice, nopause = true },
			{roles = {"VISIONIST"},			duration = 3.25,		anim = {"drink_chalice_pre", "drink_chalice" },
				castsound = {
        	        VISIONIST = "meta5/wendy/player_drink"
        	    },
			},
			{actionfn = fn.clear_chalice_symbol, nopause = true },

			{roles = {"VISIONIST"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE38_VISIONIST, anim = "emoteXL_annoyed" },
			{roles = {"VISIONIST"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE39_VISIONIST, anim = {"idle_groggy_pre", "idle_groggy"}, animtype = "loop" },
			{roles = {"VISIONIST"},			duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE40_VISIONIST, anim = { "emote_pre_sit2", "emote_loop_sit2" }, endidleanim = "emote_loop_sit2" },
			
			{roles = {"ARTIFICER"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE41_ARTIFICER, anim = "emoteXL_annoyed" },

			{roles = {"VISIONIST"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE42_VISIONIST, anim = "emote_loop_sit2", animtype = "loop"},
			{roles = {"ARTIFICER"},			duration = FRAMES},

            {
               actionfn = fn.play_sound_with_delay_fn_constructor(22 * FRAMES, "rifts6/stageplay/death_maskhit"),
               nopause = true,
                roles = {"VISIONIST"},			
            },
            {
                actionfn = fn.play_sound_with_delay_fn_constructor(22 * FRAMES, "rifts6/stageplay/death_bodyfall"),
                nopause = true,
                roles = {"VISIONIST"},			
            },
            {
               actionfn = fn.play_sound_with_delay_fn_constructor(37 * FRAMES, "rifts6/stageplay/death_handpat"),
                nopause = true,
                roles = {"VISIONIST"},	
            },
            {
                actionfn = fn.play_sound_with_delay_fn_constructor(37 * FRAMES, "rifts6/stageplay/death_maskhit"),
                nopause = true,
                roles = {"VISIONIST"},	
            },
			{
                roles = {"VISIONIST"},			duration = 1.0,		anim="architect_death", endidleanim="architect_death_idle",
            },
			{actionfn = fn.findpositions,	duration = 1.5,		positions={["ELYTRA"] = 8, ["ARTIFICER"] = 12}},
			{roles = {"ARTIFICER"},			duration = 1.0,		anim="emoteXL_annoyed", },
			{actionfn = fn.findpositions,	duration = 1.0,		positions={["ARTIFICER"] = 10}},

			-- Visionist is dead

			{actionfn = fn.override_with_dagger, nopause = true, roles = {"ELYTRA"} },
			{roles = {"ELYTRA"},			nopause = true,		anim="item_out", },
			{roles = {"ARTIFICER"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE43_ARTIFICER, anim = "emoteXL_angry" },

			{actionfn = fn.findpositions,	duration = 1.0,		positions={["ELYTRA"] = 11}},
						

			-- Elytra stabs artificer
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(0 * FRAMES, "rifts6/stageplay/swish"),
				nopause = true,
                roles = {"ARTIFICER"},
			},


			{actionfn = fn.apply_vault_dagger, roles = {"ELYTRA"}, duration = 1.5, anim={"dagger_pre", "dagger_lag", } },
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(0 * FRAMES, "rifts6/stageplay/stab"),
				nopause = true,
                roles = {"ARTIFICER"},
			},


			{actionfn = fn.clear_dagger_symbol, nopause = true, roles = {"ELYTRA"} },
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(15 * FRAMES, "rifts6/stageplay/death_handpat"),
				nopause = true,
                roles = {"ARTIFICER"},
			},
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(16 * FRAMES, "rifts6/stageplay/death_handpat"),
				nopause = true,
                roles = {"ARTIFICER"},
			},
			{actionfn = fn.apply_vault_dagger, roles = {"ARTIFICER"},			duration = 30 * FRAMES,		line = STRINGS.STAGEACTOR.THEVAULT.LINE44_ARTIFICER, anim = "mason_death_pre", animtype = "hold" },
			{roles = {"ARTIFICER"},			nopause = true,	anim = "mason_death_loop", animtype = "loop" },

			{actionfn = fn.findpositions,	duration = 0.5,		positions={["ELYTRA"] = 7}},

			{roles = {"ARTIFICER"},			duration = 4.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE45_ARTIFICER, anim = "mason_death_loop", animtype = "loop", check_current_anim = true },
			{actionfn = fn.do_emote_fx, roles = {"ARTIFICER"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE46_ARTIFICER, anim = "mason_angry_death", do_emote_sound = true, endidleanim = "mason_death_loop", loopendidleanim = true },
			{roles = {"ARTIFICER"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE47_ARTIFICER, anim = "mason_death_loop", animtype = "loop", check_current_anim = true },
			{roles = {"ARTIFICER"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE48_ARTIFICER, anim = "mason_death_loop", animtype = "loop", check_current_anim = true },
			{roles = {"ARTIFICER"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE49_ARTIFICER, anim = "mason_death_loop", animtype = "loop" },
			{roles = {"ARTIFICER"},			duration = FRAMES},
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(11 * FRAMES, "rifts6/stageplay/death_handpat"),
				nopause = true,
                roles = {"ARTIFICER"},
			},
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(10 * FRAMES, "rifts6/stageplay/death_maskhit"),
				nopause = true,
                roles = {"ARTIFICER"},
			},
			{
                actionfn = fn.play_sound_with_delay_fn_constructor(12 * FRAMES, "rifts6/stageplay/death_bodyfall"),
				nopause = true,
                roles = {"ARTIFICER"},
			},

			{
                actionfn = fn.play_sound_with_delay_fn_constructor(12 * FRAMES, "rifts6/stageplay/death_maskhit"),
				nopause = true,
                roles = {"ARTIFICER"},
			},
			{roles = {"ARTIFICER"},			duration = 3.0,		anim = "mason_death", endidleanim="mason_death_idle", },
--Artificer lines 50-53 removed
			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE54_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE55_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE56_ELYTRA, anim = "emoteXL_facepalm" },
			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE57_ELYTRA,  },

			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE58_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE59_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE60_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE61_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE62_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.5,		line = STRINGS.STAGEACTOR.THEVAULT.LINE63_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE64_ELYTRA,  },
			{roles = {"ELYTRA"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVAULT.LINE65_ELYTRA, anim = { "emote_pre_sit2", "emote_loop_sit2" }, endidleanim = "emote_loop_sit2" },

			{actionfn = fn.stopbgmusic,		duration = 4, },

			{actionfn = fn.stinger,			duration = 5,		sound = "stageplay_set/statue_lyre/stinger_outro" },

            {roles = {"BIRD1"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD1_4},
			{roles = {"BIRD2"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD2_5},
			{roles = {"BIRD1", "BIRD2"}, duration = 1.5,		line = STRINGS.STAGEACTOR.THEVAULT.BIRD_6},
			
			{roles = {"ARTIFICER"},	nopause = true, anim="mason_death_pst"},
			{roles = {"VISIONIST"},	duration = 2.0, anim="architect_death_pst"},
			
			{actionfn = fn.findpositions,	duration = 2,		positions={["ARTIFICER"] = 3,["VISIONIST"] = 2,["ELYTRA"] = 1,}},
			{actionfn = fn.actorsbow,   	duration = 2.5, },
			{actionfn = fn.marionetteoff,	duration = 1,		time = MARIONETTE_TIME},
            
            {actionfn = fn.stageoff,		duration = 0.3, },
			{actionfn = fn.exitbirds,		duration = 0.3, }, 
		}}


return {costumes=costumes, scripts=scripts, starting_act=starting_act}