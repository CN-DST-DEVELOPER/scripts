local costumes = {}
local scripts = {}

local fn = require("play_commonfn")

costumes["SAGE"]=		{ 		head ="mask_sagehat",			name= STRINGS.CAST.SAGE}
costumes["HALFWIT"]=	{ 		head ="mask_halfwithat",		name= STRINGS.CAST.HALFWIT }
costumes["TOADY"]=		{		head ="mask_toadyhat",			name= STRINGS.CAST.TOADY }


local starting_act = "THEVEIL"
-----------------------------------------------------------------------------------------------------------------
    -- COSTUME PLAYS
	scripts["SAGE_SOLILOQUY"]= {
		cast = { "SAGE" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["SAGE"] = 1,}},
         	{actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 3, },

			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[1]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[2]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[3]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[4]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[5]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[6]},
			{roles = {"SAGE"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.SAGE_SOLILOQUY[7]},

			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },
		}}


	scripts["HALFWIT_SOLILOQUY"]= {
		cast = { "HALFWIT" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["HALFWIT"] = 1,}},
         	{actionfn = fn.marionetteon,    duration = 0.1, },
			{actionfn = fn.actorsbow,		duration = 3, },

			{roles = {"HALFWIT"},		duration = 3, 	line = STRINGS.STAGEACTOR.TOADY_SOLILOQUY[1]},
			{roles = {"HALFWIT"},		duration = 1 },
			{roles = {"HALFWIT"},		duration = 3, 	line = STRINGS.STAGEACTOR.TOADY_SOLILOQUY[2]},
			{roles = {"HALFWIT"},		duration = 3,													anim ={"emoteXL_pre_dance7", "emoteXL_loop_dance7", "emoteXL_loop_dance7"} },
		
			{actionfn = fn.actorsbow,		duration = 0.2, },
            {actionfn = fn.marionetteoff,   duration = 0.1, },

		}}		

	scripts["TOADY_SOLILOQUY"]= {
		cast = { "TOADY" },
		lines = {
			{actionfn = fn.findpositions,	duration = 1, positions={["TOADY"] = 1,}},
            {actionfn = fn.marionetteon,    duration = 1, },
			

			{roles = {"TOADY"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.HALFWIT_SOLILOQUY[1]},
			{roles = {"TOADY"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.HALFWIT_SOLILOQUY[2]},
			{roles = {"TOADY"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.HALFWIT_SOLILOQUY[3]},
			{roles = {"TOADY"},		duration = 2.5, 	line = STRINGS.STAGEACTOR.HALFWIT_SOLILOQUY[4], anim = "emoteXL_angry"},		
		
            {actionfn = fn.marionetteoff,   duration = 0.1, },

		}}		


------------------------------------------------------------------------------------------------------------------
local MARIONETTE_TIME = 1.1

	-- THE PLAY
	scripts["THEVEIL"]= {
		cast = { "SAGE","TOADY","HALFWIT" },
		playbill = STRINGS.PLAYS.THEVEIL,
		next = "THEVEIL",
		lines = {
			{actionfn = fn.findpositions,	duration = 1,		positions={["SAGE"] = 1,["TOADY"] = 9,["HALFWIT"] = 10,}},

			{actionfn = fn.stageon,			duration = 1.5, },
			{actionfn = fn.stinger,			duration = 0.01,	sound = "stageplay_set/statue_lyre/stinger_intro_act1" },
			{actionfn = fn.marionetteon,	duration = 0.2,		time = MARIONETTE_TIME},
			{actionfn = fn.actorsbow,		duration = 1, },

			{actionfn = fn.callbirds,		duration = 2, },

			{roles = {"BIRD1"},				duration = 2, 		line = STRINGS.STAGEACTOR.THEVEIL.BIRD1_1},
			{roles = {"BIRD2"},				duration = 2,		line = STRINGS.STAGEACTOR.THEVEIL.BIRD2_2},
			{roles = {"BIRD1"},				duration = 2,		line = STRINGS.STAGEACTOR.THEVEIL.BIRD1_3},

			{actionfn = fn.exitbirds,		duration = 0.1, },
			{actionfn = fn.startbgmusic,	duration = 0.2,		musictype = "happy"}, --bgm_mood: stageplay_set/bgm_moods/music_happy

			--{roles = {"HALFWIT"},		duration = 1.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE40_HALFWIT, },
			--{roles = {"HALFWIT"},		duration = 2.0,		actionfn = fn.do_mask_blink },

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE1_SAGE, sgparam="upbeat"},
			{roles = {"SAGE"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE2_SAGE, },
			{roles = {"SAGE","TOADY"},	duration = 1.0,		anim="emote_waving" },
			{roles = {"HALFWIT"},		duration = 1.0,		anim="emote_waving" },

			{roles = {"TOADY"},			duration = 4.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE3_TOADY, 		anim ={"emoteXL_pre_dance7", "emoteXL_loop_dance7",  "emoteXL_loop_dance7",  "emoteXL_loop_dance7"} },

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE4_SAGE},
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE5_TOADY},
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE6_HALFWIT, 	anim="death", endidleanim="death_idle"},

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE7_SAGE, 		anim="emoteXL_angry"  },
			{roles = {"HALFWIT"},		duration = 0.1,		anim="parasite_death_pst"},
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE8_TOADY, 		anim="emoteXL_happycheer" },
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE9_HALFWIT, 	anim="emoteXL_happycheer"},
			{ duration = 1},
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE10_SAGE, },
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE11_TOADY },
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE12_HALFWIT, 	anim ={"emoteXL_pre_dance7", "emoteXL_loop_dance7"} },
			{roles = {"TOADY","SAGE"},	duration = 2.0,														  	anim="emoteXL_annoyed" },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE14_SAGE, },
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE15_TOADY, },
			{roles = {"SAGE"},			duration = 2.3,		line = STRINGS.STAGEACTOR.THEVEIL.LINE16_SAGE, },
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE17_HALFWIT, 	anim="emoteXL_happycheer" },
			{roles = {"TOADY","SAGE"},	duration = 2.0,															anim="emoteXL_annoyed" },

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE19_SAGE, 		anim="emoteXL_waving4"},
			{roles = {"SAGE"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE20_SAGE, },

			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE21_HALFWIT, 	anim="emoteXL_waving4"},
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE22_TOADY, 	anim="emoteXL_waving4"},
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE23_HALFWIT, 	anim ={"emoteXL_pre_dance7", "emoteXL_loop_dance7"}},

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE24_SAGE, 		anim="emoteXL_angry" },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE25_SAGE, },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE26_SAGE, },

			{roles = {"TOADY"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE27_TOADY, 	anim="emoteXL_happycheer" },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE28_SAGE,		anim="emoteXL_happycheer" },
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE29_HALFWIT, 	anim="emoteXL_kiss" },
			{roles = {"SAGE"},			duration = 2.2,		line = STRINGS.STAGEACTOR.THEVEIL.LINE30_SAGE, },
			{roles = {"HALFWIT"},		duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE31_HALFWIT, 	anim="emoteXL_happycheer" },

			{roles = {"SAGE"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE32_SAGE, },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE33_SAGE, },

			{actionfn = fn.startbgmusic,	duration = 0.1,		musictype = "mysterious"},

			{roles = {"TOADY"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE34_TOADY, },
			{roles = {"HALFWIT"},		duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE35_HALFWIT,  	anim="emoteXL_bonesaw" },
			{roles = {"TOADY"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE36_TOADY, },
			{roles = {"SAGE"},			duration = 3.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE37_SAGE, },
			{roles = {"HALFWIT"},		duration = 1.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE38_HALFWIT, },
			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE39_TOADY, },
			{roles = {"HALFWIT"},		duration = 1,		line = STRINGS.STAGEACTOR.THEVEIL.LINE40_HALFWIT, },			
			{roles = {"HALFWIT"},		duration = 3.5,		actionfn = fn.do_mask_blink },

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE41_SAGE, },
			{roles = {"TOADY"},			duration = 0.1,															anim={"emote_pre_toast", "emote_loop_toast", "emote_loop_toast"} },
			{roles = {"HALFWIT"},		duration = 2.0,															anim="spooked" },

			{roles = {"TOADY"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE42_TOADY, },

			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE43_SAGE, },
			{roles = {"SAGE"},			duration = 2.0,		line = STRINGS.STAGEACTOR.THEVEIL.LINE44_SAGE, },

			{actionfn = fn.enableblackout,		duration = 0.1, },
			{actionfn = fn.stopbgmusic,		duration = 1, },

			{roles = {"HALFWIT"},		duration = 1,		line = STRINGS.STAGEACTOR.THEVEIL.LINE45_HALFWIT, },
			{roles = {"TOADY","SAGE","HALFWIT"},	duration = 2.0,												anim="death", endidleanim="death_idle"},

			{actionfn = fn.disableblackout,			duration = 4 },			

			{roles = {"TOADY","SAGE","HALFWIT"},	duration = 2.0,												anim="parasite_death_pst"},

			{actionfn = fn.actorsbow,		duration = 1, },
			{actionfn = fn.stinger,			duration = 2.5,		sound = "stageplay_set/statue_lyre/stinger_outro" },
			{actionfn = fn.marionetteoff,	duration = 1,		time = MARIONETTE_TIME},
			{actionfn = fn.stageoff,		duration = 0.3, },
			--{actionfn = fn.exitbirds,		duration = 0.3, }, 
		}}

 

return {costumes=costumes, scripts=scripts, starting_act=starting_act}

