
AddRoom("Graveyard", {
					colour={r=.010,g=.010,b=.10,a=.50},
					value = WORLD_TILES.FOREST,
					tags = {"Town", "Mist"},
					contents =  {
					                countprefabs= {
					                    evergreen = 3,
                                        goldnugget = function() return math.random(5) end,
					                    gravestone = function () return 4 + math.random(4) end,
					                    mound = function () return 4 + math.random(4) end
					                }
					            }
					})
