local Biddikus, C, L, _ = unpack(select(2, ...))

Biddikus = LibStub("AceAddon-3.0"):NewAddon("Biddikus_Continued", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local screenWidth			= floor(GetScreenWidth())
local screenHeight			= floor(GetScreenHeight())

local _G		= _G
local select	= _G.select
local unpack	= _G.unpack
local type		= _G.type
local floor		= _G.math.floor
local min		= _G.math.min
local strbyte	= _G.string.byte
local format	= _G.string.format
local strlen	= _G.string.len
local strsub	= _G.string.sub
local strmatch	= _G.string.match

local pairs		= _G.pairs
local tinsert	= _G.table.insert
local sort		= _G.table.sort
local wipe		= _G.table.wipe

local GetTime				= _G.GetTime
local GetNumGroupMembers	= _G.GetNumGroupMembers
local GetNumSubgroupMembers	= _G.GetNumSubgroupMembers
local GetInstanceInfo		= _G.GetInstanceInfo
local IsInRaid				= _G.IsInRaid
local UnitAffectingCombat	= _G.UnitAffectingCombat
local UnitClass				= _G.UnitClass
local UnitExists			= _G.UnitExists
local UnitIsFriend			= _G.UnitIsFriend
local UnitCanAssist			= _G.UnitCanAssist
local UnitIsPlayer			= _G.UnitIsPlayer
local UnitName				= _G.UnitName
local UnitReaction			= _G.UnitReaction
local UnitIsUnit 			= _G.UnitIsUnit
local FindAuraByName		= AuraUtil and AuraUtil.FindAuraByName

local FACTION_BAR_COLORS	= _G.FACTION_BAR_COLORS
local RAID_CLASS_COLORS		= (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)

-- Variables
Biddikus.prefix = "Biddikus"
Biddikus.userAgent = "Biddikus-0.0.1"
Biddikus.message_welcome = "Type /biddikus for options."

Biddikus.version = C_AddOns and C_AddOns.GetAddOnMetadata("Biddikus_Continued", "Version") or GetAddOnMetadata and GetAddOnMetadata("Biddikus_Continued", "Version") or "2.0"
Biddikus.addonName = "Biddikus_Continued"

Biddikus.inRaid = false
Biddikus.playerName = nil
Biddikus.masterLooterName = nil

Biddikus.bid = {
    item = nil,
    minimum = nil,
    state = nil,
    timer = nil,
    timerCount = nil,
    timerMax = nil,
    currentBid = nil,
    currentPlayer = nil,
    currentClass = nil,
}
Biddikus.item = nil
Biddikus.dkpSyncRequested = false
Biddikus._dkpCurrentRaidContext = nil

Biddikus.RAID_LIST = {
    { key = "Karazhan",     name = "Karazhan" },
    { key = "Gruul",        name = "Gruul's Lair" },
    { key = "Magtheridon",  name = "Magtheridon" },
    { key = "SSC",          name = "Serpentshrine Cavern" },
    { key = "TK",           name = "Tempest Keep" },
    { key = "BT",           name = "Black Temple" },
    { key = "SWP",          name = "Sunwell Plateau" },
}
Biddikus.RAID_KEYS = {}
for _, r in ipairs(Biddikus.RAID_LIST) do
    Biddikus.RAID_KEYS[r.key] = r.name
end

StaticPopupDialogs["BIDDIKUS_RAID_SELECT_CONFIRM"] = {
    text = "Set raid context to %s? This will be broadcast to the raid.",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function(self, data)
        Biddikus._dkpCurrentRaidContext = data.key
        Biddikus.frame.footer.raidButton:SetText(data.name)
        Biddikus:DKPBroadcastRaidContext()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BIDDIKUS_RAID_CLEAR_CONFIRM"] = {
    text = "Clear raid selection? This will be broadcast to the raid.",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function()
        Biddikus._dkpCurrentRaidContext = nil
        Biddikus.frame.footer.raidButton:SetText("Select Raid")
        Biddikus:DKPBroadcastRaidContext()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BIDDIKUS_START_NO_RAID"] = {
    text = "No raid is selected. Start bid anyway?",
    button1 = "Start Anyway",
    button2 = "Cancel",
    OnAccept = function()
        Biddikus:SendStartBid(Biddikus.item, Biddikus.frame.footer.minbox:GetNumber(), Biddikus.db.profile.bidTimeout)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BIDDIKUS_BOSS_KILL_CONFIRM"] = {
    text = "Award %s EKP to the raid for a boss kill in %s?",
    button1 = "Award",
    button2 = "Cancel",
    OnAccept = function()
        Biddikus:DKPBossKillAward()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BIDDIKUS_FIRST_KILL_CONFIRM"] = {
    text = "Award %s EKP to the raid for a FIRST boss kill in %s?",
    button1 = "Award",
    button2 = "Cancel",
    OnAccept = function()
        Biddikus:DKPFirstKillAward()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

Biddikus.options = {
	name = "Biddikus_Continued",
	handler = Biddikus,
	type = "group",
	args = {
        general = {
            order = 1,
			type = "group",
            name = "General",
            args = {
                enable = {
                    order = 1, 
                    type = "toggle",
                    name = "Enable Biddkus",
                    desc = "Enables Biddikus bidding management",
                    get = function(info) 
                        Biddikus:UpdateFrame()
                        return(Biddikus.db.profile.enable) 
                    end,
                    set = function(info, key) Biddikus.db.profile.enable=key end
                },
                increment = {
                    order = 2, 
                    type = "range",
                    min = 0.1,
                    max = 100,
                    step = 0.1,
                    name = "Automatic Bid Increment",
                    desc = "Auto increment your next bid by this amount",
                    get = function(info) return(Biddikus.db.profile.bidIncrement) end,
                    set = function(info, key) Biddikus.db.profile.bidIncrement=key end
                },
                nickname = {
                    order = 3,
                    type = "input",
                    name = "Nickname",
                    desc = "Set a custom nickname to replace your character name during bids",
                    get = function(info) return(Biddikus.db.profile.nickname) end,
                    set = function(info, key)
                        if key == '' then
                            key = nil
                        end
                        Biddikus.db.profile.nickname=key end
                },
                flash = {
                    order = 5,
                    type = "toggle",
                    name = "Enable Screen Flash",
                    desc = "Enable bid timeout screen flash",
                    get = function(info) return(Biddikus.db.profile.flash) end,
                    set = function(info, key) Biddikus.db.profile.flash=key end
                },
                raidWarningStart = {
                    order = 6, 
                    type = "toggle",
                    name = "Enable Bid Start Warning",
                    desc = "Warns you about bid start with a raid warning message",
                    get = function(info) 
                        Biddikus:UpdateFrame()
                        return(Biddikus.db.profile.raidWarningStart) 
                    end,
                    set = function(info, key) Biddikus.db.profile.raidWarningStart=key end
                },
                raidWarningEnd = {
                    order = 7, 
                    type = "toggle",
                    name = "Enable Bid End Warnings",
                    desc = "Warns you about bids timing out",
                    get = function(info) 
                        Biddikus:UpdateFrame()
                        return(Biddikus.db.profile.raidWarningEnd) 
                    end,
                    set = function(info, key) Biddikus.db.profile.raidWarningEnd=key end
                },
                autohide = {
                    order = 8, 
                    type = "toggle",
                    name = "Auto Hide",
                    desc = "Hides Biddikus when not bidding",
                    get = function(info) 
                        Biddikus:UpdateFrame()
                        return(Biddikus.db.profile.autohide) 
                    end,
                    set = function(info, key) Biddikus.db.profile.autohide=key end
                },

            }
        },
        appearance = {
			order = 2,
			type = "group",
			name = "Appearance",
			get = function(info)
				return C[info[2]][info[3]]
			end,
			set = function(info, value)
				C[info[2]][info[3]] = value
				Biddikus:UpdateFrame()
			end,
			args = {
				frame = {
					order = 1,
					name = "Frame",
					type = "group",
					inline = true,
					args = {
						locked = {
							order = 1,
							name = "Locked",
							type = "toggle",
						},
						strata = {
							order = 2,
							name = "Strata",
							type = "select",
							values = {
								["1-BACKGROUND"] = "BACKGROUND",
								["2-LOW"] = "LOW",
								["3-MEDIUM"] = "MEDIUM",
								["4-HIGH"] = "HIGH",
								["5-DIALOG"] = "DIALOG",
								["6-FULLSCREEN"] = "FULLSCREEN",
								["7-FULLSCREEN_DIALOG"] = "FULLSCREEN_DIALOG",
								["8-TOOLTIP"] = "TOOLTIP",
							},
							style = "dropdown",
						},
						headerShow = {
							order = 3,
							name = "Show Header",
							type = "toggle",
						},
						framePosition = {
							order = 4,
							name = "Frame Position",
							type = "group",
							inline = true,
							args = {
								width = {
									order = 3,
									name = "Frame Width",
									type = "range",
									min = 64,
									max = 1024,
									step = 0.01,
									bigStep = 1,
									get = function(info)
										return C[info[2]][info[4]]
									end,
									set = function(info, value)
										C[info[2]][info[4]] = value
										Biddikus:UpdateFrame()
									end,
								},
								height = {
									order = 4,
									name = "Frame Height",
									type = "range",
									min = 10,
									max = 1024,
									step = 0.01,
									bigStep = 1,
									get = function(info)
										return C[info[2]][info[4]]
									end,
									set = function(info, value)
										C[info[2]][info[4]] = value
										Biddikus:UpdateFrame()
									end,
								},
								xOffset = {
									order = 5,
									name = "Frame xOffset",
									type = "range",
									softMin = 0,
									softMax = screenWidth,
									step = 0.01,
									bigStep = 1,
									get = function(info)
										return C[info[2]].position[4]
									end,
									set = function(info, value)
										C[info[2]].position[4] = value
										Biddikus:UpdateFrame()
									end,
								},
								yOffset = {
									order = 5,
									name = "Frame yOffset",
									type = "range",
									softMin = -screenHeight,
									softMax = 0,
									step = 0.01,
									bigStep = 1,
									get = function(info)
										return C[info[2]].position[5]
									end,
									set = function(info, value)
										C[info[2]].position[5] = value
										Biddikus:UpdateFrame()
									end,
								},
							},
						},
						scale = {
							order = 5,
							name = "Frame Scale",
							type = "range",
							min = 50,
							max = 300,
							step = 1,
							bigStep = 10,
							get = function(info)
								return C[info[2]][info[3]] * 100
							end,
							set = function(info, value)
								C[info[2]][info[3]] = value / 100
								Biddikus:UpdateFrame()
							end,
						},
						frameColors = {
							order = 6,
							name = "Color",
							type = "group",
							inline = true,
							get = function(info)
								return unpack(C[info[2]][info[4]])
							end,
							set = function(info, r, g, b, a)
								local cfg = C[info[2]][info[4]]
								cfg[1] = r
								cfg[2] = g
								cfg[3] = b
								cfg[4] = a
								Biddikus:UpdateFrame()
							end,

							args = {
								color = {
									order = 1,
									name = "Background Colour",
									type = "color",
									hasAlpha = true,
								},
								headerColor = {
									order = 2,
									name = "Header Colour",
									type = "color",
									hasAlpha = true,
								},
							},
						},
					},
				},
				bar = {
					order = 2,
					name = "Bar",
					type = "group",
                    inline = true,
					args = {
						height = {
							order = 3,
							name = "Bar Height",
							type = "range",
							min = 6,
							max = 64,
							step = 1,
                        },
					},
				},
				font = {
					order = 5,
					name = "Font",
					type = "group",
					inline = true,
					args = {
						size = {
							order = 2,
							name = "Font Size",
							type = "range",
							min = 6,
							max = 64,
							step = 1,
						},
						style = {
							order = 3,
							name = "Font Style",
							type = "select",
							values = {
								[""] = "NONE",
								["OUTLINE"] = "OUTLINE",
								["THICKOUTLINE"] = "THICKOUTLINE",
							},
							style = "dropdown",
						},
						name = {
							order = 4,
							name = "Font Name",
							type = "select",
							dialogControl = 'LSM30_Font',
							values = AceGUIWidgetLSMlists.font,
						},
						shadow = {
							order = 5,
							name = "Font Shadow",
							type = "toggle",
							width = "full",
						},
					},
				},
				reset = {
					order = 6,
					name = "Reset",
					type = "execute",
					func = function(info, value)
						Biddikus.db.profile = Biddikus.defaultOptions
						Biddikus:UpdateFrame()
					end,
				},
            },
        },
        sound = {
            order = 3,
            type = "group",
            name = "Sound",
			args = {
                enable = {
                    order = 1,
                    type = "toggle",
                    name = "Enable Sound",
                    desc = "Enable sounds",
                    get = function(info) return(Biddikus.db.profile.sound.enable) end,
                    set = function(info, key) Biddikus.db.profile.sound.enable=key end
                },
                start = {
                    order = 2,
                    type = "toggle",
                    name = "Enable Start",
                    desc = "Enable bid start notification",
                    get = function(info) return(Biddikus.db.profile.sound.start) end,
                    set = function(info, key) Biddikus.db.profile.sound.start=key end
                },
                countdown = {
                    order = 3,
                    type = "toggle",
                    name = "Enable Countdown",
                    desc = "Enable bid timeout countdown",
                    get = function(info) return(Biddikus.db.profile.sound.countdown) end,
                    set = function(info, key) Biddikus.db.profile.sound.countdown=key end
                },
                pause = {
                    order = 4,
                    type = "toggle",
                    name = "Enable Pause",
                    desc = "Enable bid pause notification",
                    get = function(info) return(Biddikus.db.profile.sound.pause) end,
                    set = function(info, key) Biddikus.db.profile.sound.pause=key end
                },
                resume = {
                    order = 5,
                    type = "toggle",
                    name = "Enable Resume",
                    desc = "Enable bid resume notification",
                    get = function(info) return(Biddikus.db.profile.sound.resume) end,
                    set = function(info, key) Biddikus.db.profile.sound.resume=key end
                },
                raidWarningSound = {
                    order = 6,
                    type = "toggle",
                    name = "Enable Raid Warning",
                    desc = "Enable Raid Warning sound",
                    get = function(info) return(Biddikus.db.profile.sound.raidWarningSound) end,
                    set = function(info, key) Biddikus.db.profile.sound.raidWarningSound=key end
                }
            }
        },
        masterlooter = {
            order = 4,
            type = "group",
            name = "Masterlooter",
			args = {
                bidTimeout = {
                    order = 1,
                    type = "range",
                    min = 15,
                    max = 180,
                    step = 1,
                    name = "Bid Timeout",
                    desc = "Set the starting and maximum time on a bid timer",
                    get = function(info) return(Biddikus.db.profile.bidTimeout) end,
                    set = function(info, key) Biddikus.db.profile.bidTimeout=key end
                },
                bidMinimum = {
                    order = 2,
                    type = "input",
                    name = "Minimum Bid",
                    desc = "Set the starting bid value",
                    get = function(info)
                        Biddikus:UpdateFrame()
                        return(Biddikus.db.profile.bidMinimum)
                    end,
                    set = function(info, key) Biddikus.db.profile.bidMinimum=key end
                },
                postLoot = {
                    order = 3,
                    type = "toggle",
                    name = "Post Loot",
                    desc = "Post looted items into raid chat",
                    get = function(info) return(Biddikus.db.profile.postLoot) end,
                    set = function(info, key) Biddikus.db.profile.postLoot=key end
                },
                qualityThreshold = {
                    order = 4,
                    type = "range",
                    min = 0,
                    max = 8,
                    step = 1,
                    name = "Item Quality",
                    desc = "Set the item quality threshold for posting to raid chat",
                    get = function(info) return(Biddikus.db.profile.qualityThreshold) end,
                    set = function(info, key) Biddikus.db.profile.qualityThreshold=key end
                },
            }
        },
        dkp = {
            order = 5,
            type = "group",
            name = "DKP",
            args = {
                officerStatus = {
                    order = 1,
                    type = "group",
                    inline = true,
                    name = "Officer Status",
                    args = {
                        statusDesc = {
                            order = 1,
                            type = "description",
                            name = function()
                                if Biddikus:IsDKPOfficer() then
                                    return "|cFF00FF00You are a DKP officer.|r Officer permissions are based on your guild rank (Guild Master or Officer)."
                                elseif IsInGuild() then
                                    return "|cFFAAAAAAYou are not a DKP officer.|r Officer permissions are based on your guild rank (Guild Master or Officer)."
                                else
                                    return "|cFFAAAAAAYou are not in a guild.|r Join a guild with officer privileges to manage DKP."
                                end
                            end,
                            fontSize = "medium",
                            width = "full",
                        },
                    },
                },
                biddingSettings = {
                    order = 1.5,
                    type = "group",
                    inline = true,
                    name = "Bidding Settings",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = {
                        secondPricePlusOne = {
                            order = 1,
                            type = "toggle",
                            name = "Second-Price +1 Bidding",
                            desc = "When enabled, the winner pays the 2nd highest bid + 1 instead of their full bid. If only one bidder, they pay the minimum bid. Discourages overbidding while preventing lowballing.",
                            width = "full",
                            get = function()
                                return Biddikus.db and Biddikus.db.profile.dkp and Biddikus.db.profile.dkp.secondPricePlusOne
                            end,
                            set = function(info, val)
                                Biddikus.db.profile.dkp.secondPricePlusOne = val
                            end,
                        },
                        secondPriceDesc = {
                            order = 2,
                            type = "description",
                            name = "|cFFAAAAAAExample:|r |cFF44AAFFPlayer A|r bids |cFFFFD1009|r, |cFF44AAFFPlayer B|r bids |cFFFFD10015|r. |cFF00FF00Player B wins and pays 10|r |cFFAAAAAA(9 + 1).|r",
                            fontSize = "medium",
                            width = "full",
                        },
                    },
                },
                raidActions = {
                    order = 2,
                    type = "group",
                    inline = true,
                    name = "Raid Actions",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = {
                        startingDKP = {
                            order = 1,
                            type = "range",
                            name = "Starting DKP",
                            desc = "Default DKP for newly added players",
                            min = 0,
                            max = 1000,
                            step = 1,
                            bigStep = 10,
                            get = function(info) return Biddikus.db.profile.dkp.defaultAmount end,
                            set = function(info, val) Biddikus.db.profile.dkp.defaultAmount = val end,
                        },
                        compileRaid = {
                            order = 2,
                            type = "execute",
                            name = "Compile Raid List",
                            desc = "Scan raid roster and add missing members with starting DKP",
                            func = function() Biddikus:DKPCompileRaid() end,
                        },
                        awardAmount = {
                            order = 3,
                            type = "input",
                            name = "Award Amount",
                            desc = "Amount of DKP to award to the entire raid",
                            get = function(info) return Biddikus._dkpAwardAmount or "" end,
                            set = function(info, val) Biddikus._dkpAwardAmount = val end,
                        },
                        awardNote = {
                            order = 4,
                            type = "input",
                            name = "Award Note",
                            desc = "Reason for the DKP award",
                            get = function(info) return Biddikus._dkpAwardNote or "" end,
                            set = function(info, val) Biddikus._dkpAwardNote = val end,
                        },
                        awardRaid = {
                            order = 5,
                            type = "execute",
                            name = "Award DKP to Raid",
                            desc = "Award the specified DKP amount to all current raid members in the standings",
                            func = function()
                                local amount = tonumber(Biddikus._dkpAwardAmount)
                                if not amount or amount == 0 then
                                    print("|cFFFF0000[Biddikus DKP]|r Enter a valid award amount.")
                                    return
                                end
                                Biddikus:DKPAwardRaid(amount, Biddikus._dkpAwardNote or "")
                                Biddikus._dkpAwardAmount = ""
                                Biddikus._dkpAwardNote = ""
                            end,
                            confirm = true,
                            confirmText = "Award DKP to all raid members in standings?",
                        },
                    },
                },
                bossKillSettings = {
                    order = 2.5,
                    type = "group",
                    inline = true,
                    name = "Boss Kill EKP Settings",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = (function()
                        local args = {}
                        for i, r in ipairs(Biddikus.RAID_LIST) do
                            args["bossKill_" .. r.key] = {
                                order = i,
                                type = "range",
                                name = r.name .. " (per boss)",
                                desc = "EKP awarded per boss kill in " .. r.name,
                                min = 0,
                                max = 50,
                                step = 1,
                                get = function()
                                    local dkp = Biddikus.db and Biddikus.db.profile.dkp
                                    return dkp and dkp.bossKillAmounts and dkp.bossKillAmounts[r.key] or 0
                                end,
                                set = function(info, val)
                                    if not Biddikus.db.profile.dkp.bossKillAmounts then
                                        Biddikus.db.profile.dkp.bossKillAmounts = {}
                                    end
                                    Biddikus.db.profile.dkp.bossKillAmounts[r.key] = val
                                end,
                            }
                        end
                        args.firstKillAmount = {
                            order = 20,
                            type = "range",
                            name = "First Kill Bonus",
                            desc = "Bonus EKP awarded for a first-time boss kill (on top of normal boss kill EKP)",
                            min = 0,
                            max = 50,
                            step = 1,
                            get = function()
                                local dkp = Biddikus.db and Biddikus.db.profile.dkp
                                return dkp and dkp.firstKillAmount or 5
                            end,
                            set = function(info, val)
                                Biddikus.db.profile.dkp.firstKillAmount = val
                            end,
                        }
                        return args
                    end)(),
                },
                individualAdjust = {
                    order = 3,
                    type = "group",
                    inline = true,
                    name = "Individual Adjustment",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = {
                        player = {
                            order = 1,
                            type = "select",
                            name = "Player",
                            desc = "Select a player to adjust",
                            values = function()
                                local vals = {}
                                if Biddikus.db and Biddikus.db.profile.dkp then
                                    for name, data in pairs(Biddikus.db.profile.dkp.standings) do
                                        local hex = Biddikus:DKPGetClassColor(data.class)
                                        vals[name] = format("|cFF%s%s|r [%d DKP]", hex, name, data.current)
                                    end
                                end
                                return vals
                            end,
                            get = function(info) return Biddikus._dkpAdjustPlayer end,
                            set = function(info, val) Biddikus._dkpAdjustPlayer = val end,
                        },
                        amount = {
                            order = 2,
                            type = "input",
                            name = "Amount (+/-)",
                            desc = "Amount to add (positive) or subtract (negative)",
                            get = function(info) return Biddikus._dkpAdjustAmount or "" end,
                            set = function(info, val) Biddikus._dkpAdjustAmount = val end,
                        },
                        note = {
                            order = 3,
                            type = "input",
                            name = "Note",
                            desc = "Reason for the adjustment",
                            get = function(info) return Biddikus._dkpAdjustNote or "" end,
                            set = function(info, val) Biddikus._dkpAdjustNote = val end,
                        },
                        apply = {
                            order = 4,
                            type = "execute",
                            name = "Apply Adjustment",
                            desc = "Apply the DKP adjustment to the selected player",
                            func = function()
                                local player = Biddikus._dkpAdjustPlayer
                                local amount = tonumber(Biddikus._dkpAdjustAmount)
                                if not player or not amount or amount == 0 then
                                    print("|cFFFF0000[Biddikus DKP]|r Select a player and enter a valid amount.")
                                    return
                                end
                                Biddikus:DKPAdjustPlayer(player, amount, Biddikus._dkpAdjustNote or "")
                                Biddikus._dkpAdjustAmount = ""
                                Biddikus._dkpAdjustNote = ""
                            end,
                            confirm = true,
                            confirmText = "Apply this DKP adjustment?",
                        },
                    },
                },
                standings = {
                    order = 4,
                    type = "group",
                    inline = true,
                    name = "Current Standings",
                    args = {
                        standingsSummary = {
                            order = 1,
                            type = "description",
                            name = function()
                                if not Biddikus.db or not Biddikus.db.profile.dkp then return "" end
                                local count = 0
                                for _ in pairs(Biddikus.db.profile.dkp.standings) do count = count + 1 end
                                return "|cFFAAAAAA" .. count .. " players tracked  (v" .. Biddikus.db.profile.dkp.syncVersion .. ")|r"
                            end,
                            fontSize = "medium",
                            width = "full",
                        },
                        showStandings = {
                            order = 2,
                            type = "execute",
                            name = "Open DKP Standings",
                            desc = "Open the DKP standings table with sortable columns",
                            func = function() Biddikus:ShowDKPStandings() end,
                        },
                        exportCSV = {
                            order = 2.5,
                            type = "execute",
                            name = "Export CSV",
                            desc = "Export DKP standings as CSV text for copying",
                            func = function() Biddikus:ShowDKPExportCSV() end,
                        },
                        requestSync = {
                            order = 3,
                            type = "execute",
                            name = "Request Sync",
                            desc = "Request DKP data from officers in the raid",
                            func = function() Biddikus:DKPRequestSync() end,
                        },
                        broadcastDKP = {
                            order = 4,
                            type = "execute",
                            name = "Broadcast DKP",
                            desc = "Broadcast full DKP state to the raid",
                            hidden = function() return not Biddikus:IsDKPOfficer() end,
                            func = function() Biddikus:DKPBroadcastFull("RAID") end,
                        },
                        requestGuildSync = {
                            order = 5,
                            type = "execute",
                            name = "Request Guild Sync",
                            desc = "Request DKP data from officers in your guild",
                            func = function() Biddikus:DKPRequestGuildSync() end,
                        },
                        broadcastGuildDKP = {
                            order = 6,
                            type = "execute",
                            name = "Broadcast DKP to Guild",
                            desc = "Broadcast full DKP state to the guild",
                            hidden = function() return not Biddikus:IsDKPOfficer() end,
                            func = function() Biddikus:DKPBroadcastFull("GUILD") end,
                        },
                    },
                },
                lootHistory = {
                    order = 5,
                    type = "group",
                    inline = true,
                    name = "Loot History",
                    args = {
                        lootSummary = {
                            order = 1,
                            type = "description",
                            name = function()
                                if not Biddikus.db or not Biddikus.db.profile.dkp then return "" end
                                local count = #(Biddikus.db.profile.dkp.lootHistory or {})
                                return "|cFFAAAAAA" .. count .. " items recorded.|r"
                            end,
                            fontSize = "medium",
                            width = "full",
                        },
                        showLootHistory = {
                            order = 2,
                            type = "execute",
                            name = "Open Loot History",
                            desc = "Open the loot history window with date filtering",
                            func = function() Biddikus:ShowDKPLootHistory() end,
                        },
                    },
                },
                personalHistory = {
                    order = 5.5,
                    type = "group",
                    inline = true,
                    name = "Personal Transaction History",
                    args = {
                        personalDesc = {
                            order = 1,
                            type = "description",
                            name = "|cFFAAAAAAView your personal DKP transactions including awards, deductions, decays, and adjustments.|r",
                            fontSize = "medium",
                            width = "full",
                        },
                        showPersonalHistory = {
                            order = 2,
                            type = "execute",
                            name = "Open My Transactions",
                            desc = "Open your personal transaction history with sortable columns",
                            func = function() Biddikus:ShowDKPPersonalHistory() end,
                        },
                    },
                },
                dkpLog = {
                    order = 6,
                    type = "group",
                    inline = true,
                    name = "DKP Log",
                    args = {
                        logText = {
                            order = 1,
                            type = "description",
                            name = function() return Biddikus:DKPGetLogText() end,
                            fontSize = "medium",
                            width = "full",
                        },
                    },
                },
                decay = {
                    order = 7,
                    type = "group",
                    inline = true,
                    name = "Weekly Decay",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = {
                        decayStatus = {
                            order = 1,
                            type = "description",
                            name = function()
                                if not Biddikus.db or not Biddikus.db.profile.dkp then return "" end
                                local last = Biddikus.db.profile.dkp.lastDecayDate
                                if last == "" then
                                    return "|cFFFF8800Decay has never been applied.|r"
                                end
                                local overdue = Biddikus:DKPIsDecayOverdue()
                                if overdue then
                                    return "|cFFFF0000Last decay: " .. last .. " — OVERDUE!|r"
                                end
                                return "|cFF00FF00Last decay: " .. last .. " — Up to date.|r"
                            end,
                            fontSize = "medium",
                            width = "full",
                        },
                        applyDecay = {
                            order = 2,
                            type = "execute",
                            name = "Apply 10% Decay",
                            desc = "Reduce all player EKP by 10% (weekly Tuesday decay)",
                            func = function() Biddikus:DKPApplyDecay() end,
                            confirm = true,
                            confirmText = "Apply 10% decay to ALL player EKP? This affects every player in standings.",
                        },
                    },
                },
                dangerZone = {
                    order = 8,
                    type = "group",
                    inline = true,
                    name = "Danger Zone",
                    hidden = function() return not Biddikus:IsDKPOfficer() end,
                    args = {
                        resetAll = {
                            order = 1,
                            type = "execute",
                            name = "Reset All DKP",
                            desc = "Wipe all DKP standings and logs. This cannot be undone!",
                            func = function() Biddikus:DKPResetAll() end,
                            confirm = true,
                            confirmText = "Are you SURE you want to reset ALL DKP data? This cannot be undone!",
                        },
                    },
                },
            },
        },
	}
}
Biddikus.defaultOptions = {
	profile = {
        enable = true,
        bidIncrement = 5,
        bidTimeout = 30,
        bidMinimum = 1,
        nickname = nil,
        flash = false,
        raidWarningStart = false,
        raidWarningEnd = false,
        autohide = false,
        postLoot = true,
        qualityThreshold = 4,
        sound = {
            enable = true,
            start = true,
            countdown = true,
            pause = true,
            resume = true,
            raidWarningSound = false,
        },
        frame = {
            scale				= 1,									-- global scale
            width				= 217,									-- frame width
            height				= 161,									-- frame height
            locked				= false,								-- toggle for movable
            strata				= "3-MEDIUM",							-- frame strata
            position			= {"TOPLEFT", "UIParent", "TOPLEFT", 50, -200},	-- frame position
            color				= {0, 0, 0, 0.35},						-- frame background color
            headerShow			= true,									-- show frame header
            headerColor			= {0, 0, 0, 0.8},						-- frame header color
            minHeight           = 18,
        },
        backdrop = {
            bgTexture			= defaultTexture,						-- backdrop texture
            bgColor				= {1, 1, 1, 0.1},						-- backdrop color
            edgeTexture			= defaultTexture,						-- backdrop edge texture
            edgeColor			= {0, 0, 0, 1},							-- backdrop edge color
            tile				= false,								-- backdrop texture tiling
            tileSize			= 0,									-- backdrop tile size
            edgeSize			= 1,									-- backdrop edge size
            inset				= 0,									-- backdrop inset value
        },
        font = {
            name 				= defaultFont,							-- font name
            size				= 12,									-- font size
            style				= "OUTLINE",							-- font style
            color				= {1, 1, 1, 1},							-- font color
            shadow				= true,									-- font dropshadow
        },
        bar = {
            height				= 18,									-- bar height
        },
        dkp = {
            enabled = true,
            standings = {},
            defaultAmount = 0,
            log = {},
            lootHistory = {},
            lastDecayDate = "",
            secondPricePlusOne = false,
            lastSyncTimestamp = 0,
            syncVersion = 0,
            bossKillAmounts = {
                Karazhan = 1,
                Gruul = 5,
                Magtheridon = 10,
                SSC = 0,
                TK = 0,
                BT = 0,
                SWP = 0,
            },
            firstKillAmount = 5,
        },
    },
}

local LSM = LibStub("LibSharedMedia-3.0")
-- Register some media
LSM:Register("sound", "Priority1", [[Interface\AddOns\Biddikus_Continued\media\sound\fgandi.ogg]])
LSM:Register("sound", "Priority2", [[Interface\AddOns\Biddikus_Continued\media\sound\xelaxus.ogg]])
LSM:Register("sound", "Priority3", [[Interface\AddOns\Biddikus_Continued\media\sound\limlife.ogg]])
LSM:Register("sound", "Priority4", [[Interface\AddOns\Biddikus_Continued\media\sound\limtotem.ogg]])
LSM:Register("sound", "Priority5", [[Interface\AddOns\Biddikus_Continued\media\sound\limtank.ogg]])
LSM:Register("sound", "Priority6", [[Interface\AddOns\Biddikus_Continued\media\sound\bane1.ogg]])
LSM:Register("sound", "Priority7", [[Interface\AddOns\Biddikus_Continued\media\sound\bane2.ogg]])
LSM:Register("sound", "Priority8", [[Interface\AddOns\Biddikus_Continued\media\sound\bus1.ogg]])
LSM:Register("sound", "Priority9", [[Interface\AddOns\Biddikus_Continued\media\sound\bus2.ogg]])
LSM:Register("sound", "Priority10", [[Interface\AddOns\Biddikus_Continued\media\sound\dotskekw.ogg]])
LSM:Register("sound", "Priority11", [[Interface\AddOns\Biddikus_Continued\media\sound\beanwtflim.ogg]])
LSM:Register("sound", "Priority12", [[Interface\AddOns\Biddikus_Continued\media\sound\beanhappening.ogg]])
LSM:Register("sound", "Priority13", [[Interface\AddOns\Biddikus_Continued\media\sound\lisp1.ogg]])
LSM:Register("sound", "Priority14", [[Interface\AddOns\Biddikus_Continued\media\sound\tsbdotsdumb.ogg]])
LSM:Register("sound", "Priority15", [[Interface\AddOns\Biddikus_Continued\media\sound\dotsdead.ogg]])
LSM:Register("sound", "Priority16", [[Interface\AddOns\Biddikus_Continued\media\sound\limbeanmule.ogg]])
LSM:Register("sound", "Priority17", [[Interface\AddOns\Biddikus_Continued\media\sound\xel3.ogg]])
LSM:Register("sound", "Priority18", [[Interface\AddOns\Biddikus_Continued\media\sound\limhappy.ogg]])
LSM:Register("sound", "Priority19", [[Interface\AddOns\Biddikus_Continued\media\sound\xelglaives.ogg]])
LSM:Register("sound", "Priority20", [[Interface\AddOns\Biddikus_Continued\media\sound\xelgood.ogg]])
LSM:Register("sound", "Priority21", [[Interface\AddOns\Biddikus_Continued\media\sound\xeldeadlim.ogg]])
LSM:Register("sound", "Priority22", [[Interface\AddOns\Biddikus_Continued\media\sound\xeltoken.ogg]])
LSM:Register("sound", "Priority23", [[Interface\AddOns\Biddikus_Continued\media\sound\xeltsbbop.ogg]])
LSM:Register("sound", "Priority24", [[Interface\AddOns\Biddikus_Continued\media\sound\casstupidgame.ogg]])
LSM:Register("sound", "Priority25", [[Interface\AddOns\Biddikus_Continued\media\sound\limpull.ogg]])
LSM:Register("sound", "Priority26", [[Interface\AddOns\Biddikus_Continued\media\sound\tsbbop2.ogg]])
LSM:Register("sound", "Priority27", [[Interface\AddOns\Biddikus_Continued\media\sound\xelbeaten.ogg]])
LSM:Register("sound", "Priority28", [[Interface\AddOns\Biddikus_Continued\media\sound\tsbshart.ogg]])
LSM:Register("sound", "Priority29", [[Interface\AddOns\Biddikus_Continued\media\sound\dotsdryballs.ogg]])
LSM:Register("sound", "Priority30", [[Interface\AddOns\Biddikus_Continued\media\sound\tsbyikes.ogg]])
LSM:Register("sound", "Priority31", [[Interface\AddOns\Biddikus_Continued\media\sound\xelsquawk.ogg]])
LSM:Register("sound", "Priority32", [[Interface\AddOns\Biddikus_Continued\media\sound\YEP.ogg]])
LSM:Register("sound", "Priority33", [[Interface\AddOns\Biddikus_Continued\media\sound\beandruid.ogg]])
LSM:Register("sound", "Priority34", [[Interface\AddOns\Biddikus_Continued\media\sound\casstoken.ogg]])
LSM:Register("sound", "Priority35", [[Interface\AddOns\Biddikus_Continued\media\sound\beanattention.ogg]])
LSM:Register("sound", "Priority36", [[Interface\AddOns\Biddikus_Continued\media\sound\beanhate.ogg]])
LSM:Register("sound", "Reset", [[Interface\AddOns\Biddikus_Continued\media\sound\reset.ogg]])
LSM:Register("sound", "Pause", [[Interface\AddOns\Biddikus_Continued\media\sound\pause.ogg]])
LSM:Register("sound", "1", [[Interface\AddOns\Biddikus_Continued\media\sound\Kolt\1.ogg]])
LSM:Register("sound", "2", [[Interface\AddOns\Biddikus_Continued\media\sound\Kolt\2.ogg]])
LSM:Register("sound", "3", [[Interface\AddOns\Biddikus_Continued\media\sound\Kolt\3.ogg]])
LSM:Register("sound", "4", [[Interface\AddOns\Biddikus_Continued\media\sound\Kolt\4.ogg]])
LSM:Register("sound", "5", [[Interface\AddOns\Biddikus_Continued\media\sound\Kolt\5.ogg]])
LSM:Register("font", "NotoSans SemiCondensedBold", [[Interface\AddOns\Biddikus_Continued\media\NotoSans-SemiCondensedBold.ttf]])
LSM:Register("font", "Standard Text Font", _G.STANDARD_TEXT_FONT) -- register so it's usable as a default in config
LSM:Register("statusbar", "Biddikus Default", [[Interface\ChatFrame\ChatFrameBackground]]) -- register so it's usable as a default in config

if not EasyMenu then
	function EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		if displayMode == "MENU" then
			menuFrame.displayMode = displayMode
		end
		UIDropDownMenu_Initialize(menuFrame, function(self, level)
			for i, v in ipairs(menuList) do
				v.index = i
				UIDropDownMenu_AddButton(v, level)
			end
		end, displayMode)
		ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
	end
end

local SoundChannels = {
	["Master"] = "Master",
	["SFX"] =  "SFX",
	["Ambience"] =  "Ambience",
	["Music"] = "Music"
}

-----------------------------
-- Frame
-----------------------------
Biddikus.frame = CreateFrame("Frame", Biddikus.addonName.."Frame", UIParent)

local function UpdateFont(fs, size)
	fs:SetFont(LSM:Fetch("font", C.font.name), C.font.size - size, C.font.style)
	fs:SetVertexColor(unpack(C.font.color))
	fs:SetShadowOffset(C.font.shadow and 1 or 0, C.font.shadow and -1 or 0)
end

local function CreateFS(parent)
	local fs = parent:CreateFontString(nil, "ARTWORK")
	fs:SetFont(LSM:Fetch("font", C.font.name), C.font.size, C.font.style)
	return fs
end

local function SetPosition(f)
	local _, _, _, x, y = f:GetPoint()
	C.frame.position = {"TOPLEFT", "UIParent", "TOPLEFT", x, y}
end

local function OnDragStart(f)
	if not C.frame.locked then
		f = f:GetParent()
		f:StartMoving()
	end
end

local function OnDragStop(f)
	if not C.frame.locked then
		f = f:GetParent()
		-- make sure to call before StopMovingOrSizing, or frame anchors will be broken
		-- see https://wowwiki.fandom.com/wiki/API_Frame_StartMoving
		SetPosition(f)
		f:StopMovingOrSizing()

	end
end

local function UpdateSize(f)
	C.frame.width = f:GetWidth() - 2
	C.frame.height = f:GetHeight()

	Biddikus:UpdateFrame()
end

local function OnResizeStart(f)
	Biddikus.frame.header:SetMovable(false)
	f = f:GetParent()
	if f.SetResizeBounds then
		f:SetResizeBounds(64, C.bar.height, 512, 1024)
	elseif f.SetMinResize then
		f:SetMinResize(64, C.bar.height)
		f:SetMaxResize(512, 1024)
	end
	Biddikus.sizing = true
	f:SetScript("OnSizeChanged", UpdateSize)
	f:StartSizing()
end

local function OnResizeStop(f)
	Biddikus.frame.header:SetMovable(true)
	f = f:GetParent()
	Biddikus.sizing = false
	f:SetScript("OnSizeChanged", nil)
	f:StopMovingOrSizing()
end

function Biddikus:FlashScreen()
	if not self.FlashFrame then
		local flasher = CreateFrame("Frame", "BiddikusFlashFrame")
		flasher:SetToplevel(true)
		flasher:SetFrameStrata("FULLSCREEN_DIALOG")
		flasher:SetAllPoints(UIParent)
		flasher:EnableMouse(false)
		flasher:Hide()
		flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
		flasher.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		flasher.texture:SetAllPoints(UIParent)
		flasher.texture:SetBlendMode("ADD")
		flasher:SetScript("OnShow", function(self)
			self.elapsed = 0
			self:SetAlpha(0)
		end)
		flasher:SetScript("OnUpdate", function(self, elapsed)
			elapsed = self.elapsed + elapsed
			if elapsed < 2.6 then
				local alpha = elapsed % 1.3
				if alpha < 0.15 then
					self:SetAlpha(alpha / 0.15)
				elseif alpha < 0.9 then
					self:SetAlpha(1 - (alpha - 0.15) / 0.6)
				else
					self:SetAlpha(0)
				end
			else
				self:Hide()
			end
			self.elapsed = elapsed
		end)
		self.FlashFrame = flasher
	end

	self.FlashFrame:Show()
end

function Biddikus:UpdateFrame()
	local frame = self.frame

	if not Biddikus.sizing then
        frame:SetSize(C.frame.width + 2, C.frame.height)
	end
	frame:ClearAllPoints()
	frame:SetPoint(unpack(C.frame.position))
	frame:SetScale(C.frame.scale)
	frame:SetFrameStrata(strsub(C.frame.strata, 3))

    if not C.frame.locked then
		frame:SetMovable(true)
		if frame.SetResizable then frame:SetResizable(true) end
		frame:SetClampedToScreen(true)

		frame.resize:Show()
		frame.resize:EnableMouse(true)
		frame.resize:SetMovable(true)
		frame.resize:RegisterForDrag("LeftButton")
		frame.resize:SetScript("OnDragStart", OnResizeStart)
		frame.resize:SetScript("OnDragStop", OnResizeStop)

		frame.header:SetMovable(true)
		frame.header:SetClampedToScreen(true)
		frame.header:RegisterForDrag("LeftButton")
		frame.header:SetScript("OnDragStart", OnDragStart)
		frame.header:SetScript("OnDragStop", OnDragStop)
    else
		frame:SetMovable(false)
		if frame.SetResizable then frame:SetResizable(false) end
		frame.resize:Hide()
		frame.resize:SetMovable(false)
		frame.header:SetMovable(false)
	end

	-- Background
	frame.bg:SetAllPoints()
    frame.bg:SetVertexColor(unpack(C.frame.color))
    
    
    frame.itemcontainer:SetSize(C.frame.width, C.bar.height)
    frame.itemcontainer.item:SetSize(C.bar.height - 3, C.bar.height - 3)
    frame.itemcontainer.text:SetSize(C.frame.width - 3 - C.bar.height, C.bar.height - 3)
    frame.itemcontainer.timer:SetSize(C.frame.width - 3, C.bar.height - 3)
    frame.history:SetSize(C.frame.width - 6, C.frame.height - C.bar.height - (C.bar.height + 6))
    local bidcontainerOffset = 0
    if not C.frame.locked then
        bidcontainerOffset = 15
    else
        bidcontainerOffset = 0
    end
    frame.bidcontainer:SetSize(C.frame.width - bidcontainerOffset, C.bar.height)
    frame.bidbox:SetSize(C.frame.width * 2/3 - bidcontainerOffset - 6, C.bar.height)
    frame.bidbutton:SetSize(C.frame.width * 1/3 - 3, C.bar.height)

    frame.header.text:SetPoint("LEFT", frame.header, C.bar.height + 2, -1)
    frame.history:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -C.bar.height)
    frame.itemcontainer.text:SetPoint("LEFT", frame.itemcontainer, C.bar.height + 3, -1)
    frame.itemcontainer.timer:SetPoint("RIGHT", frame.itemcontainer, 0, -1)

    frame.history:SetFont(LSM:Fetch("font", C.font.name), C.font.size -2, C.font.style)
    frame.itemcontainer.text:SetFont(LSM:Fetch("font", C.font.name), C.font.size-1, C.font.style)
    frame.bidbox:SetFont(LSM:Fetch("font", C.font.name), C.font.size, C.font.style)

    frame.bidbutton:SetEnabled(false)

    frame.itemcontainer.timer:SetText(self.bid.timerCount)

    UpdateFont(frame.itemcontainer.text, -1)
    UpdateFont(frame.itemcontainer.timer, -1)

    if self.bid.timerCount then
        if self.bid.timerCount < 6 and self.bid.timerCount > 0 then
            frame.itemcontainer.timer:SetTextColor(1, 0, 0, 1)
        end
    end

    if Biddikus.bid.item then

        local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(Biddikus.bid.item)
        frame.itemcontainer.text:SetText(itemName)
        if itemQuality then
            r, g, b = GetItemQualityColor(itemQuality)
            frame.itemcontainer.text:SetTextColor(r, g, b, 1)
        end
        frame.itemcontainer.item.texture:SetAllPoints()
        frame.itemcontainer.item.texture:SetTexture(itemTexture)

        Biddikus:SetBidAmount()

        if Biddikus.bid.state == "OPEN" then
            frame.bidbutton:SetEnabled(true)
        else
            frame.bidbutton:SetEnabled(false)
        end

        -- If you are winning, disable button
        if Biddikus.bid.currentPlayer == (C.nickname and C.nickname or self.playerName) then
            frame.bidbutton:SetEnabled(false)
        end
    end

    -- force clear bid box
    if Biddikus.bid.state == "CLOSED" then
        frame.bidbox:SetText("")
    end

	-- Header
    if C.frame.headerShow then
        frame.header.logo:SetSize(C.bar.height - 2, C.bar.height - 2)
        frame.header.text:SetSize(C.frame.width / 2, C.bar.height)
        frame.header:SetSize(C.frame.width + 2, C.bar.height)

        frame.header:SetPoint("TOPLEFT", frame, 0, C.bar.height - 1)
        frame.header.text:SetPoint("LEFT", self.frame.header, C.bar.height + 2, -1)
	    frame.header.bg:SetAllPoints()
	    frame.header.bg:SetVertexColor(unpack(C.frame.headerColor))

        frame.header.text:SetText("Biddikus")

		UpdateFont(frame.header.text, 0)

        -- DKP Balance display
        if frame.header.dkpText then
            frame.header.dkpText:SetSize(C.frame.width / 2 - 4, C.bar.height)
            frame.header.dkpText:ClearAllPoints()
            frame.header.dkpText:SetPoint("RIGHT", frame.header, "RIGHT", -4, -1)
            UpdateFont(frame.header.dkpText, 2)
            self:DKPUpdateBalanceDisplay()
        end

		frame.header:Show()
	else
		frame.header:Hide()
    end

    -- Footer
    frame.footer:Hide()
    if self:CheckIfMasterLooter() then
        frame.footer:SetSize(C.frame.width + 2, C.bar.height*4 + 15)

		frame.footer:SetPoint("BOTTOMLEFT", frame, 0, -C.bar.height*4 - 15)
	    frame.footer.bg:SetAllPoints()
        frame.footer.bg:SetVertexColor(unpack(C.frame.color))

        -- Row 1: Raid context selector
        frame.footer.raidLabel:SetSize(C.frame.width * 1/4 - 3, C.bar.height)
        frame.footer.raidLabel:ClearAllPoints()
        frame.footer.raidLabel:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", 6, -3)
        frame.footer.raidLabel:SetFont(LSM:Fetch("font", C.font.name), C.font.size, C.font.style)
        frame.footer.raidButton:SetSize(C.frame.width * 3/4 - 3, C.bar.height)
        frame.footer.raidButton:ClearAllPoints()
        frame.footer.raidButton:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", -3, -3)
        -- Update button text to reflect current raid context
        if Biddikus._dkpCurrentRaidContext then
            frame.footer.raidButton:SetText(Biddikus.RAID_KEYS[Biddikus._dkpCurrentRaidContext] or "Select Raid")
        else
            frame.footer.raidButton:SetText("Select Raid")
        end

        -- Row 2: Item name, min box, start button
        local row2Top = -(C.bar.height + 6)
        frame.footer.text:SetSize(C.frame.width * 2/4 -3, C.bar.height)
        frame.footer.minbox:SetSize(C.frame.width * 1/4 -3, C.bar.height)
        frame.footer.startbutton:SetSize(C.frame.width * 1/4 -3, C.bar.height)

        frame.footer.text:SetFont(LSM:Fetch("font", C.font.name), C.font.size, C.font.style)
        frame.footer.minbox:SetFont(LSM:Fetch("font", C.font.name), C.font.size, C.font.style)

        frame.footer.text:ClearAllPoints()
        frame.footer.minbox:ClearAllPoints()
        frame.footer.startbutton:ClearAllPoints()
        frame.footer.text:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", 3, row2Top)
        frame.footer.minbox:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", -(C.frame.width * 1/4 + 3), row2Top)
        frame.footer.startbutton:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", -3, row2Top)

        -- Row 3: Pause, Resume, End, Clear
        local row3Top = -(C.bar.height*2 + 9)
        frame.footer.pausebutton:SetSize(C.frame.width * 1/4 -3, C.bar.height)
        frame.footer.resumebutton:SetSize(C.frame.width * 1/4 -3, C.bar.height)
        frame.footer.endbutton:SetSize(C.frame.width * 1/4 -3, C.bar.height)
        frame.footer.clearbutton:SetSize(C.frame.width * 1/4 -3, C.bar.height)

        frame.footer.pausebutton:ClearAllPoints()
        frame.footer.resumebutton:ClearAllPoints()
        frame.footer.endbutton:ClearAllPoints()
        frame.footer.clearbutton:ClearAllPoints()
        frame.footer.pausebutton:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", 3, row3Top)
        frame.footer.resumebutton:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", (C.frame.width * 1/4 + 3), row3Top)
        frame.footer.endbutton:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", -(C.frame.width * 1/4 + 3), row3Top)
        frame.footer.clearbutton:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", -3, row3Top)

        -- Row 4: Boss Kill, First Kill
        frame.footer.bossKillButton:SetSize(C.frame.width * 1/2 -3, C.bar.height)
        frame.footer.firstKillButton:SetSize(C.frame.width * 1/2 -3, C.bar.height)
        frame.footer.bossKillButton:ClearAllPoints()
        frame.footer.firstKillButton:ClearAllPoints()
        frame.footer.bossKillButton:SetPoint("BOTTOMLEFT", frame.footer, "BOTTOMLEFT", 3, 3)
        frame.footer.firstKillButton:SetPoint("BOTTOMRIGHT", frame.footer, "BOTTOMRIGHT", -3, 3)

        frame.footer.minbox:SetNumber(string.format("%.2f", C.bidMinimum))

        if Biddikus.item then
            local itemName, itemLink, itemQual = GetItemInfo(Biddikus.item)
            frame.footer.text:SetText(itemName)
            r, g, b = GetItemQualityColor(itemQual)
            frame.footer.text:SetTextColor(r, g, b, 1)
        end

        if Biddikus.bid.state == "OPEN" then
            frame.footer.startbutton:SetEnabled(false)
        else
            frame.footer.startbutton:SetEnabled(true)
        end

        frame.footer:Show()
    else
        frame.footer:Hide()
    end

    if C.autohide and not Biddikus.bid.item then
        frame:SetSize(C.frame.width + 2, 1)
        if not Biddikus:CheckIfMasterLooter() then
            frame.header:Hide()
        end
        frame.bidcontainer:Hide()
        frame.itemcontainer:Hide()
        frame.bg:SetVertexColor(0, 0, 0, 0)
    else
        frame:SetSize(C.frame.width + 2, C.frame.height)
        frame.header:Show()
        frame.bidcontainer:Show()
        frame.itemcontainer:Show()
        frame.bg:SetVertexColor(unpack(C.frame.color))
    end

    if C.enable then
        frame:Show()
    else
        frame:Hide()
    end
end

local function CreateBackdrop(parent, cfg)
	local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", -cfg.inset, cfg.inset)
	f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", cfg.inset, -cfg.inset)
	-- Backdrop Settings
	local backdrop = {
		edgeFile = LSM:Fetch("statusbar", cfg.edgeTexture),
		tile = cfg.tile,
		tileSize = cfg.tileSize,
		edgeSize = cfg.edgeSize,
		insets = {
			left = cfg.inset,
			right = cfg.inset,
			top = cfg.inset,
			bottom = cfg.inset,
		},
	}
	f:SetBackdrop(backdrop)
	f:SetBackdropColor(unpack(cfg.bgColor))
	f:SetBackdropBorderColor(unpack(cfg.edgeColor))

	parent.backdrop = f
end

-----------------------------
-- SETUP
-----------------------------
function Biddikus:SetupFrame()
	self.frame:SetFrameLevel(1)
	self.frame:ClearAllPoints()
	self.frame:SetPoint(unpack(C.frame.position))

	self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	self.frame.bg:SetColorTexture(1, 1, 1, 1)

	self.frame.resize = CreateFrame("Frame", self.addonName.."Resize", self.frame)
	self.frame.resize:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
	self.frame.resize:SetSize(12, 12)
	self.frame.resizeTexture = self.frame.resize:CreateTexture()
	self.frame.resizeTexture:SetTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
	self.frame.resizeTexture:SetDesaturated(true)
	self.frame.resizeTexture:SetPoint("TOPLEFT", self.frame.resize)
	self.frame.resizeTexture:SetPoint("BOTTOMRIGHT", self.frame.resize, "BOTTOMRIGHT", 0, 0)

	-- Setup Header
    self.frame.header = CreateFrame("Frame", nil, self.frame)
    CreateBackdrop(self.frame.header, C.backdrop)

	self.frame.header:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			EasyMenu(Biddikus.menuTable, Biddikus.menu, "cursor", 0, 0, "MENU")
		end
	end)
	self.frame.header:EnableMouse(true)

	self.frame.header.text = CreateFS(self.frame.header)
    self.frame.header.text:SetJustifyH("LEFT")
    self.frame.header.bg = self.frame.header:CreateTexture(nil, "BACKGROUND", nil, -8)
    self.frame.header.bg:SetColorTexture(1, 1, 1, 1)

    self.frame.header.logo = CreateFrame("Frame", "ItemIcon", self.frame.header)
    self.frame.header.logo:SetPoint("LEFT", self.frame.header, 3, 0)
    self.frame.header.logo.texture = self.frame.header.logo:CreateTexture(nil, "ARTWORK")
    self.frame.header.logo.texture:SetAllPoints()
    self.frame.header.logo.texture:SetTexture([[Interface\AddOns\Biddikus_Continued\media\adtlogo.tga]], false)

    -- DKP Balance text in header
    self.frame.header.dkpText = CreateFS(self.frame.header)
    self.frame.header.dkpText:SetJustifyH("RIGHT")

    -- Setup Item Display
    self.frame.itemcontainer = CreateFrame("Frame", "ItemContainer", self.frame)
    self.frame.itemcontainer:SetPoint("TOP")

    self.frame.itemcontainer.item = CreateFrame("Frame", "ItemIcon", self.frame.itemcontainer)
    self.frame.itemcontainer.item:SetPoint("LEFT", self.frame.itemcontainer, 3, -1)
    self.frame.itemcontainer.item:EnableMouse(true)
    self.frame.itemcontainer.item.texture = self.frame.itemcontainer.item:CreateTexture(nil,"ARTWORK")
    self.frame.itemcontainer.item.texture:SetColorTexture(1, 1, 1, 1)

    self.frame.itemcontainer.text = CreateFS(self.frame.itemcontainer)
    self.frame.itemcontainer.text:SetPoint("LEFT", self.frame.itemcontainer, C.bar.height + 3, 0)
    self.frame.itemcontainer.text:SetJustifyH("LEFT")

    self.frame.itemcontainer.timer = CreateFS(self.frame.itemcontainer)
    self.frame.itemcontainer.timer:SetJustifyH("RIGHT")    
    
    -- Setup Bid History
    self.frame.history = CreateFrame("ScrollingMessageFrame", "BidHistory", self.frame)
    self.frame.history:SetJustifyH("LEFT")
    self.frame.history:SetFading(false)
    self.frame.history:SetInsertMode("BOTTOM")

    -- Setup Bidding
    self.frame.bidcontainer = CreateFrame("Frame", "BidContainer", self.frame)
    self.frame.bidcontainer:SetPoint("BOTTOMLEFT")

    self.frame.bidbox = CreateFrame("EditBox", "BidBox", self.frame.bidcontainer)
    self.frame.bidbox:SetPoint("LEFT", self.frame.bidcontainer, "LEFT", 3, 3)
    self.frame.bidbox:SetMovable(false)
    self.frame.bidbox:SetAutoFocus(false)
    self.frame.bidbox:SetMultiLine(false)
    self.frame.bidbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.frame.bidbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.frame.bidbox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    self.frame.bidbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    CreateBackdrop(self.frame.bidbox, C.backdrop)

    self.frame.bidbutton = CreateFrame("Button", "BidButton", self.frame.bidcontainer)
    self.frame.bidbutton:SetPoint("RIGHT", self.frame.bidcontainer, "RIGHT", -3, 3)
    self.frame.bidbutton:SetText("Bid")
    self.frame.bidbutton:SetDisabledFontObject(GameFontDisable)
    self.frame.bidbutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.bidbutton:SetNormalFontObject(GameFontNormal)
    self.frame.bidbutton:SetScript("OnClick", function(self, arg1)
        amount = Biddikus.frame.bidbox:GetNumber()
        if amount > 0 then
            Biddikus:SendBid(Biddikus.frame.bidbox:GetNumber())
        end
        Biddikus.frame.bidbox:ClearFocus()
    end)
    
    CreateBackdrop(self.frame.bidbutton, C.backdrop)

    -- Setup Masterloot Footer
    self.frame.footer = CreateFrame("Frame", nil, self.frame)

    self.frame.footer.bg = self.frame.footer:CreateTexture(nil, "BACKGROUND", nil, -8)
    self.frame.footer.bg:SetColorTexture(1, 1, 1, 1)

    self.frame.footer.text = CreateFS(self.frame.footer)
    self.frame.footer.text:SetJustifyH("LEFT")

    self.frame.footer.minbox = CreateFrame("EditBox", "MinBox", self.frame.footer)
    self.frame.footer.minbox:SetMovable(false)
    self.frame.footer.minbox:SetAutoFocus(false)
    self.frame.footer.minbox:SetMultiLine(false)
    self.frame.footer.minbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.frame.footer.minbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.frame.footer.minbox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    self.frame.footer.minbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    self.frame.footer.minbox:SetNumber(string.format("%.2f", C.bidMinimum))
    CreateBackdrop(self.frame.footer.minbox, C.backdrop)

    self.frame.footer.startbutton = CreateFrame("Button", "StartButton", self.frame.footer)
    self.frame.footer.startbutton:SetText("Start")
    self.frame.footer.startbutton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.startbutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.startbutton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.startbutton:SetScript("OnClick", function(self, arg1)
        if not Biddikus._dkpCurrentRaidContext then
            StaticPopup_Show("BIDDIKUS_START_NO_RAID")
            return
        end
        Biddikus:SendStartBid(Biddikus.item, Biddikus.frame.footer.minbox:GetNumber(), C.bidTimeout)
    end)
    CreateBackdrop(self.frame.footer.startbutton, C.backdrop)

    self.frame.footer.pausebutton = CreateFrame("Button", "PauseButton", self.frame.footer)
    self.frame.footer.pausebutton:SetText("Pause")
    self.frame.footer.pausebutton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.pausebutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.pausebutton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.pausebutton:SetScript("OnClick", function(self, arg1)
        Biddikus:SendPauseBid()
    end)
    CreateBackdrop(self.frame.footer.pausebutton, C.backdrop)

    self.frame.footer.resumebutton = CreateFrame("Button", "ResumeButton", self.frame.footer)
    self.frame.footer.resumebutton:SetText("Resume")
    self.frame.footer.resumebutton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.resumebutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.resumebutton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.resumebutton:SetScript("OnClick", function(self, arg1)
        Biddikus:SendUnpauseBid()
    end)
    CreateBackdrop(self.frame.footer.resumebutton, C.backdrop)

    self.frame.footer.endbutton = CreateFrame("Button", "EndButton", self.frame.footer)
    self.frame.footer.endbutton:SetText("End")
    self.frame.footer.endbutton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.endbutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.endbutton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.endbutton:SetScript("OnClick", function(self, arg1)
        Biddikus:SendEndBid()
    end)
    CreateBackdrop(self.frame.footer.endbutton, C.backdrop)

    self.frame.footer.clearbutton = CreateFrame("Button", "ClearButton", self.frame.footer)
    self.frame.footer.clearbutton:SetText("Clear")
    self.frame.footer.clearbutton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.clearbutton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.clearbutton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.clearbutton:SetScript("OnClick", function(self, arg1)
        Biddikus:SendClearBid()
    end)
    CreateBackdrop(self.frame.footer.clearbutton, C.backdrop)

    -- Raid context selector row
    self.frame.footer.raidLabel = CreateFS(self.frame.footer)
    self.frame.footer.raidLabel:SetJustifyH("LEFT")
    self.frame.footer.raidLabel:SetText("Raid:")

    self.frame.footer.raidButton = CreateFrame("Button", "BiddikusRaidContextButton", self.frame.footer)
    self.frame.footer.raidButton:SetText("Select Raid")
    self.frame.footer.raidButton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.raidButton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.raidButton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.raidButton:SetScript("OnClick", function(btn, arg1)
        local menuList = {}
        tinsert(menuList, {
            text = "No Raid Selected",
            notCheckable = false,
            checked = (Biddikus._dkpCurrentRaidContext == nil),
            func = function()
                StaticPopup_Show("BIDDIKUS_RAID_CLEAR_CONFIRM")
            end,
        })
        for _, r in ipairs(Biddikus.RAID_LIST) do
            tinsert(menuList, {
                text = r.name,
                notCheckable = false,
                checked = (Biddikus._dkpCurrentRaidContext == r.key),
                func = function()
                    StaticPopup_Show("BIDDIKUS_RAID_SELECT_CONFIRM", r.name, nil, { key = r.key, name = r.name })
                end,
            })
        end
        EasyMenu(menuList, Biddikus.menu, "cursor", 0, 0, "MENU")
    end)
    CreateBackdrop(self.frame.footer.raidButton, C.backdrop)

    -- Boss Kill Award buttons
    self.frame.footer.bossKillButton = CreateFrame("Button", "BiddikusBossKillButton", self.frame.footer)
    self.frame.footer.bossKillButton:SetText("Boss Kill")
    self.frame.footer.bossKillButton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.bossKillButton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.bossKillButton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.bossKillButton:SetScript("OnClick", function()
        local raidKey = Biddikus._dkpCurrentRaidContext
        if not raidKey then
            print("|cFFFF0000[Biddikus DKP]|r Select a raid first.")
            return
        end
        local dkp = Biddikus.db and Biddikus.db.profile.dkp
        local amount = dkp and dkp.bossKillAmounts and dkp.bossKillAmounts[raidKey] or 0
        local raidName = Biddikus.RAID_KEYS[raidKey] or raidKey
        StaticPopup_Show("BIDDIKUS_BOSS_KILL_CONFIRM", amount, raidName)
    end)
    CreateBackdrop(self.frame.footer.bossKillButton, C.backdrop)

    self.frame.footer.firstKillButton = CreateFrame("Button", "BiddikusFirstKillButton", self.frame.footer)
    self.frame.footer.firstKillButton:SetText("First Kill")
    self.frame.footer.firstKillButton:SetDisabledFontObject(GameFontDisable)
    self.frame.footer.firstKillButton:SetHighlightFontObject(GameFontHighlight)
    self.frame.footer.firstKillButton:SetNormalFontObject(GameFontNormal)
    self.frame.footer.firstKillButton:SetScript("OnClick", function()
        local raidKey = Biddikus._dkpCurrentRaidContext
        if not raidKey then
            print("|cFFFF0000[Biddikus DKP]|r Select a raid first.")
            return
        end
        local dkp = Biddikus.db and Biddikus.db.profile.dkp
        local bossAmount = dkp and dkp.bossKillAmounts and dkp.bossKillAmounts[raidKey] or 0
        local firstBonus = dkp and dkp.firstKillAmount or 5
        local total = bossAmount + firstBonus
        local raidName = Biddikus.RAID_KEYS[raidKey] or raidKey
        StaticPopup_Show("BIDDIKUS_FIRST_KILL_CONFIRM", total .. " (Kill: " .. bossAmount .. " + Bonus: " .. firstBonus .. ")", raidName)
    end)
    CreateBackdrop(self.frame.footer.firstKillButton, C.backdrop)

    if not self:CheckIfMasterLooter() then
        self.frame.footer:Hide()
    end

    self.frame.itemcontainer.item:HookScript("OnEnter", function()
        if Biddikus.bid.item then
            GameTooltip:SetOwner(Biddikus.frame, "ANCHOR_TOP")
            GameTooltip:SetHyperlink(Biddikus.bid.item)
            GameTooltip:Show()
        end
    end)
       
    self.frame.itemcontainer.item:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

	self:UpdateFrame()
end

function Biddikus:SetupMenu()
	self.menu = CreateFrame("Frame", self.addonName.."MenuFrame", UIParent, "UIDropDownMenuTemplate")

	Biddikus.menuTable = {
        {text = "Lock", notCheckable = false, checked = function() return C.frame.locked end, func = function()
            C.frame.locked = not C.frame.locked
			Biddikus:UpdateFrame()
		end},
		{text = "DKP Standings", notCheckable = true, func = function()
			Biddikus:ShowDKPStandings()
		end},
		{text = "Loot History", notCheckable = true, func = function()
			Biddikus:ShowDKPLootHistory()
		end},
		{text = "My Transactions", notCheckable = true, func = function()
			Biddikus:ShowDKPPersonalHistory()
		end},
		{text = "Guild Sync", notCheckable = true, func = function()
			Biddikus:DKPRequestGuildSync()
		end},
		{text = "Configuration", notCheckable = true, func = function()
			LibStub("AceConfigDialog-3.0"):Open("Biddikus_Continued")
		end},
	}
end

-----------------------------
-- Events
-----------------------------
function Biddikus:OnInitialize() 
    Biddikus:RegisterEvent("PLAYER_LOGIN")
	initialized = true
end

  function Biddikus:OnEnable()
    if not initialized then self:OnInitialize() end

    Biddikus:RegisterEvent("LOOT_OPENED")
    Biddikus:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function Biddikus:OnDisable()
    Biddikus:UnregisterEvent("PLAYER_LOGIN")
    Biddikus:UnregisterEvent("LOOT_OPENED")
    Biddikus:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

function Biddikus:PLAYER_LOGIN()
    self.db = LibStub("AceDB-3.0"):New("BiddikusDB", self.defaultOptions)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Biddikus_Continued", self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Biddikus_Continued", "Biddikus_Continued")

    C = self.db.profile

    self.playerName = UnitName("player")

    self:SetupFrame()
	self:SetupMenu()

	self:RegisterChatCommand("biddikus", "ChatCommand")

    if C.welcome then
        print("|c008CB84F"..self.addonName.." v"..self.version.." - "..self.message_welcome.."|r")
    end

    self:UnregisterAllComm()
	self:RegisterComm(Biddikus.prefix)

    -- Check for overdue decay after a short delay
    self:ScheduleTimer(function()
        Biddikus:DKPCheckDecayOnLogin()
    end, 5)

    self:UnregisterEvent("PLAYER_LOGIN")
    self.PLAYER_LOGIN = nil
end

function Biddikus:LOOT_OPENED()
    if C.enable then
        if IsInRaid() then
           if self:CheckIfMasterLooter() then
                Biddikus:ListLoot()
           end
        end
    end
end

function Biddikus:GROUP_ROSTER_UPDATE()
    if C.enable then
        if IsInRaid() then
            if GetLootMethod then
                local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
                if lootMethod == "master" then
                    self.masterLooterName = GetRaidRosterInfo(masterLooterRaidID);
                else
                    self.masterLooterName = nil
                end
            else
                -- Master Loot unavailable, fall back to raid leader/assistant
                if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
                    self.masterLooterName = self.playerName
                else
                    self.masterLooterName = nil
                end
            end
        else
            self.masterLooterName = nil
        end
        self:UpdateFrame()

        -- DKP auto-sync: non-officers request sync once when joining a raid
        if IsInRaid() and not self.dkpSyncRequested then
            if not self:IsDKPOfficer() then
                self.dkpSyncRequested = true
                self:ScheduleTimer(function()
                    if IsInRaid() then
                        Biddikus:DKPRequestSync()
                    end
                end, 3)
            end
        end
        if not IsInRaid() then
            self.dkpSyncRequested = false
        end
    end
end

-----------------------------
-- Comms
-----------------------------

function Biddikus:SendComm(data, channel)
    self:SendCommMessage(self.prefix, self:Serialize(data), channel or "RAID")
end

function Biddikus:SendBid(amount)
    if self.bid.state == "OPEN" then
        if self:ValidateBid(amount) then
            localized, englishClass = UnitClass(self.playerName)
            payload = {
                messageType = "BID",
                playerName = self.playerName,
                playerNick = C.nickname and C.nickname or self.playerName, 
                playerClass = englishClass,
                bidAmount = amount,
            }
            self:SendComm(payload)
        else
            self:SetBidAmount()
        end
    end
end

function Biddikus:SendStartBid(item, minimum, timer)
    if self:CheckIfMasterLooter() then
        payload = {
            messageType = "START",
            item = item,
            minimum = minimum,
            timer = timer,
            rand = math.random(1,36)
        }
        self:SendComm(payload)
        SendChatMessage("[Biddikus] bid for " .. item .. " starting!", "RAID")
    end
end

function Biddikus:SendEndBid()
    if self:CheckIfMasterLooter() then
        local originalBid = self.bid.currentBid
        local paidAmount = originalBid
        local secondBid = self.bid.secondHighestBid
        -- Calculate second-price +1 if enabled
        if C.dkp and C.dkp.secondPricePlusOne and originalBid then
            if secondBid then
                paidAmount = secondBid + 1
            else
                -- Single bidder pays the minimum bid
                paidAmount = self.bid.minimum or originalBid
            end
        end
        payload = {
            messageType = "END",
            playerName = self.bid.currentPlayer,
            playerNick = self.bid.currentPlayerNick,
            playerClass = self.bid.currentClass,
            bidAmount = paidAmount,
            originalBid = originalBid,
            secondHighestBid = secondBid,
        }
        self:SendComm(payload)
    end
end
function Biddikus:SendPauseBid()
    if self:CheckIfMasterLooter() then
        payload = {
            messageType = "PAUSE"
        }
        self:SendComm(payload)
    end
end

function Biddikus:SendUnpauseBid()
    if self:CheckIfMasterLooter() then
        payload = {
            messageType = "UNPAUSE"
        }
        self:SendComm(payload)
    end
end

function Biddikus:SendClearBid()
    if self:CheckIfMasterLooter() then
        payload = {
            messageType = "CLEAR"
        }
        self:SendComm(payload)
    end
end

function Biddikus:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= Biddikus.prefix then return end

    -- RAID channel: handle all message types (bids, DKP sync, etc.)
    if distribution == "RAID" then
        local success, payload = Biddikus:Deserialize(message)
        if not success then
            print("Deserialization Error")
            return
        end
        if payload.messageType == "BID" then
            self:ProcessBid(payload.playerName, payload.playerNick, payload.playerClass, payload.bidAmount)
        end
        if payload.messageType == "START" then
            self:SetupBid(payload.item, payload.minimum, payload.timer, payload.rand)
        end
        if payload.messageType == "END" then
            self:EndBid(payload.playerName, payload.playerNick, payload.playerClass, payload.bidAmount, payload.originalBid, payload.secondHighestBid)
        end
        if payload.messageType == "PAUSE" then
            self:PauseBid()
        end
        if payload.messageType == "UNPAUSE" then
            self:UnpauseBid()
        end
        if payload.messageType == "CLEAR" then
            self:ClearBid()
        end
        if payload.messageType == "DKP_FULL_SYNC" then
            self:DKPReceiveFullSync(payload, sender)
        end
        if payload.messageType == "DKP_REQUEST_SYNC" then
            self:DKPHandleSyncRequest(sender, "RAID")
        end
        if payload.messageType == "DKP_SET_RAID" then
            Biddikus._dkpCurrentRaidContext = payload.raidKey
        end
        self:UpdateFrame()
    end

    -- GUILD channel: only handle DKP sync messages
    if distribution == "GUILD" then
        local success, payload = Biddikus:Deserialize(message)
        if not success then return end
        if payload.messageType == "DKP_FULL_SYNC" then
            self:DKPReceiveFullSync(payload, sender)
            self:UpdateFrame()
        end
        if payload.messageType == "DKP_REQUEST_SYNC" then
            self:DKPHandleSyncRequest(sender, "GUILD")
        end
    end
end

-----------------------------
-- Functions
-----------------------------

function Biddikus:SetBidAmount()
    if Biddikus.bid.currentBid then
        if not Biddikus.frame.bidbox:HasFocus() then
            typedBid = Biddikus.frame.bidbox:GetNumber()
            if typedBid <= Biddikus.bid.currentBid then
                Biddikus.frame.bidbox:SetNumber(string.format("%.2f", Biddikus.bid.currentBid + C.bidIncrement))
            end
        end
    else 
        if not Biddikus.frame.bidbox:HasFocus() then
            typedBid = Biddikus.frame.bidbox:GetNumber()
            if typedBid <= Biddikus.bid.minimum then
                Biddikus.frame.bidbox:SetNumber(string.format("%.2f", Biddikus.bid.minimum))
            end
        end
    end
end

function Biddikus:ProcessBid(player, playerNick, class, amount)
    if self:ValidateBid(amount) then
        r, g, b = GetClassColor(class)
        local bidText = string.format("%.2f", amount) .. " - " .. playerNick
        -- Append DKP balance if available and backfill class
        if self.db and self.db.profile.dkp and self.db.profile.dkp.enabled then
            local shortName = strmatch(player, "^([^%-]+)") or player
            local data = self.db.profile.dkp.standings[shortName]
            if data then
                bidText = bidText .. " [" .. data.current .. " DKP]"
                if class and (not data.class or data.class == "") then
                    data.class = class
                end
            end
        end
        self.frame.history:AddMessage(bidText, r, g, b)
        self.bid.secondHighestBid = self.bid.currentBid  -- track for second-price +1
        self.bid.currentBid = amount
        self.bid.currentPlayer = player
        self.bid.currentPlayerNick = playerNick
        self.bid.currentClass = class
        self.bid.timerCount = self.bid.timerCount + 10
        if self.bid.timerCount > self.bid.timerMax then
            self.bid.timerCount = self.bid.timerMax
        end
        self:SetBidAmount()
    end
end

function Biddikus:ValidateBid(amount)
    if self.bid.state == "OPEN" then
        if self.bid.currentBid == nil then
            if amount >= self.bid.minimum then
                return true
            end
        else 
            if amount > self.bid.currentBid then
                return true
            end
        end
    end
    return false
end

function Biddikus:SetupBid(item, minimum, timer, rand)
    if item then
        if C.sound.enable and C.sound.start then PlaySoundFile(LSM:Fetch("sound", "Priority" .. rand), "Master") end
        if C.raidWarningStart then
            RaidNotice_AddMessage(RaidWarningFrame, "[Biddikus] " .. item .. " starting!", ChatTypeInfo["RAID_WARNING"]);
        end
        if C.sound.raidWarningSound then
            PlaySound(8959, "Master");
        end        
        self.bid = {
            item = item,
            minimum = minimum,
            state = "OPEN",
            timer = self:ScheduleRepeatingTimer("CountdownTracker", 1),
            timerCount = timer,
            timerMax = timer,
            currentBid = nil,
            secondHighestBid = nil,
            currentPlayer = nil,
            currentClass = nil,
        }
        self.frame.history:Clear()
        if Biddikus.frame.bidbox:GetNumber() < self.bid.minimum then
            Biddikus.frame.bidbox:SetNumber(string.format("%.2f", self.bid.minimum))
        end
    end
end

function Biddikus:EndBid(player, playerNick, class, amount, originalBid, secondHighestBid)
    if self.bid.state then
        self.bid.state = "CLOSED"
        self.bid.currentBid = amount
        self.bid.currentPlayer = player
        self.bid.currentPlayerNick = playerNick
        self.bid.currentClass = class
        self:CancelTimer(self.bid.timer)
        self.bid.timerCount = nil
        self.bid.timerMax = nil
        if self.bid.currentPlayer then
            self.frame.history:AddMessage("Sold! Congratulations " .. playerNick .. ".")
            if self:CheckIfMasterLooter() then
                local chatMsg = "[Biddikus] " .. self.bid.item .. " sold to " .. player .. " for " .. string.format("%.2f", amount) .. "dkp."
                -- Show second-price detail if it was applied
                if originalBid and originalBid ~= amount then
                    chatMsg = chatMsg .. " (Bid: " .. string.format("%.2f", originalBid)
                    if secondHighestBid then
                        chatMsg = chatMsg .. ", 2nd: " .. string.format("%.2f", secondHighestBid)
                    end
                    chatMsg = chatMsg .. ")"
                end
                chatMsg = chatMsg .. "  Congratulations!"
                SendChatMessage(chatMsg, "RAID")
                -- DKP: record loot win and auto-deduct
                if C.dkp and C.dkp.enabled and self:IsDKPOfficer() then
                    self:DKPRecordLoot(player, class, amount, self.bid.item)
                    self:DKPAutoDeduct(player, amount, self.bid.item)
                end
            end
        else
            self.frame.history:AddMessage(self.bid.item .. " is unwanted.  So sad..")
            if self:CheckIfMasterLooter() then
                SendChatMessage("[Biddikus] " .. self.bid.item .. " has rotted.", "RAID")
            end
        end
    end
    self.frame.bidbox:SetText("")
    self:UpdateFrame()
end

function Biddikus:PauseBid()
    if self.bid.state == "OPEN" then
        if C.sound.enable and C.sound.pause then PlaySoundFile(LSM:Fetch("sound", "Pause"), "Master") end
        self.bid.state = "PAUSED"
        self.frame.history:AddMessage("Pausing bidding...")
        self:CancelTimer(self.bid.timer)
    end
end

function Biddikus:UnpauseBid()
    if self.bid.state == "PAUSED" then
        if C.sound.enable and C.sound.resume then PlaySoundFile(LSM:Fetch("sound", "Reset"), "Master") end
        self.bid.state = "OPEN"
        self.frame.history:AddMessage("Resuming bidding...")
        self.bid.timer = self:ScheduleRepeatingTimer("CountdownTracker", 1)
    end
end

function Biddikus:ClearBid()
    self.bid = {
        item = nil,
        minimum = nil,
        state = nil,
        timer = self:CancelTimer(self.bid.timer),
        timerCount = nil,
        timerMax = nil,
        currentBid = nil,
        secondHighestBid = nil,
        currentPlayer = nil,
        currentClass = nil,
    }
    self.frame.itemcontainer.text:SetText("")
    self.frame.footer.text:SetText("")
    self.item = nil
    self.frame.bidbox:SetText("")
    self.frame.history:Clear()
    self.frame.itemcontainer.item.texture:SetTexture("")
    self.frame.itemcontainer.timer:SetText("")
    self:UpdateFrame()
end

function Biddikus:CountdownTracker()
    if self.bid.timerCount then
        self.bid.timerCount = self.bid.timerCount - 1

        if self.bid.timerCount < 6 and self.bid.timerCount > 0 then
            if C.sound.enable and C.sound.countdown then PlaySoundFile(LSM:Fetch("sound", tostring(self.bid.timerCount)), "Master") end
            if C.raidWarningEnd then
                RaidNotice_AddMessage(RaidWarningFrame, "[Biddikus] Ending in " .. tostring(self.bid.timerCount) .. "!", ChatTypeInfo["RAID_WARNING"]);
            end
            if C.sound.raidWarningSound then
                PlaySound(8959, "Master");
            end
            self.frame.history:AddMessage(self.bid.timerCount, 1, 0, 0)
            if C.flash then
                self:FlashScreen()
            end
        end
    end 

    if self.bid.timerCount == 0 then
        if self:CheckIfMasterLooter() then
            self:SendEndBid()
        end
        self.bid.timerCount = nil
        self:CancelTimer(self.bid.timer)
    end
    self:UpdateFrame()

end


function Biddikus:CheckIfMasterLooter()
    if self.playerName == self.masterLooterName then
        return true
    end
	return false
end


-- Check Rarity
-- Checks if Epic or Legendary
function Biddikus:CheckRarity(item)
    if item then
        local itemName, itemLink, itemQual = GetItemInfo(item)
        if (itemQual >= C.qualityThreshold) then
            return true
        end
    end
    return false
end

-- LIST_LOOT
-- This iterates through the items in an open loot window and lists them in raid chat
-- may change this to list items in window
function Biddikus:ListLoot()
    if C.postLoot then
        for i=1, GetNumLootItems() do
            local itemLink=GetLootSlotLink(i)
            if self:CheckRarity(itemLink) then
                i = i + 1
                SendChatMessage("[Biddikus] " .. itemLink, "RAID")
            end
        end
    end
end

function Biddikus:ChatCommand()
    LibStub("AceConfigDialog-3.0"):Open("Biddikus_Continued")
end

-----------------------------
-- DKP System
-----------------------------

function Biddikus:IsDKPOfficer()
    if self.playerName == "Srumar" then return true end
    if not IsInGuild() then return false end
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name then
            local shortName = strmatch(name, "^([^%-]+)") or name
            if shortName == self.playerName then
                -- rankIndex 0 = GM, 1 = first officer rank
                return rankIndex <= 1
            end
        end
    end
    return false
end

function Biddikus:DKPGetClassColor(class)
    if not class or class == "" then return "AAAAAA" end
    local colors = RAID_CLASS_COLORS[class]
    if colors then
        return format("%02x%02x%02x", colors.r * 255, colors.g * 255, colors.b * 255)
    end
    return "AAAAAA"
end

function Biddikus:SetupDKPStandingsFrame()
    if self.dkpStandingsFrame then return end

    local ROW_HEIGHT = 20
    local NUM_ROWS = 16
    local FRAME_W = 440
    local CONTENT_TOP = -58
    local FRAME_H = -CONTENT_TOP + NUM_ROWS * ROW_HEIGHT + 36
    local COL = { rank = 10, name = 40, class = 170, current = 270, lifetime = 350 }

    local f = CreateFrame("Frame", "BiddikusDKPStandings", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText("|cFFFFD100DKP Standings|r")

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Export CSV button
    f.exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.exportBtn:SetSize(80, 20)
    f.exportBtn:SetPoint("RIGHT", f.closeBtn, "LEFT", -2, 0)
    f.exportBtn:SetText("Export CSV")
    f.exportBtn:SetNormalFontObject("GameFontNormalSmall")
    f.exportBtn:SetHighlightFontObject("GameFontHighlightSmall")
    f.exportBtn:SetScript("OnClick", function() Biddikus:ShowDKPExportCSV() end)

    -- Column header background
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    headerBg:SetColorTexture(0.15, 0.15, 0.15, 1)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -34)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -34)
    headerBg:SetHeight(22)

    -- Sort state
    f.sortColumn = "current"
    f.sortAscending = false

    -- Column header factory
    local headerDisplayNames = { name = "Player", class = "Class", current = "Current", lifetime = "Lifetime" }
    local function MakeHeader(parent, text, x, w, sortKey, justify)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -35)
        btn:SetSize(w, 20)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if justify == "CENTER" then
            btn.label:SetPoint("CENTER", 0, 0)
            btn.label:SetJustifyH("CENTER")
        else
            btn.label:SetPoint("LEFT", 2, 0)
        end
        btn.label:SetText("|cFFFFD100" .. text .. "|r")
        btn.sortKey = sortKey
        btn.baseText = text
        if sortKey then
            btn:SetScript("OnClick", function()
                if parent.sortColumn == sortKey then
                    parent.sortAscending = not parent.sortAscending
                else
                    parent.sortColumn = sortKey
                    parent.sortAscending = (sortKey == "name" or sortKey == "class")
                end
                Biddikus:UpdateDKPStandingsFrame()
            end)
            btn:SetScript("OnEnter", function(self)
                self.label:SetText("|cFFFFFFFF" .. self.baseText .. "|r")
            end)
            btn:SetScript("OnLeave", function(self)
                local arrow = ""
                if parent.sortColumn == self.sortKey then
                    arrow = parent.sortAscending and "  |cFF888888^|r" or "  |cFF888888v|r"
                end
                self.label:SetText("|cFFFFD100" .. self.baseText .. "|r" .. arrow)
            end)
        end
        return btn
    end

    f.headers = {
        MakeHeader(f, "#", COL.rank, 28, nil),
        MakeHeader(f, "Player", COL.name, 125, "name"),
        MakeHeader(f, "Class", COL.class, 95, "class"),
        MakeHeader(f, "Current", COL.current, 80, "current", "CENTER"),
        MakeHeader(f, "Lifetime", COL.lifetime, 55, "lifetime", "CENTER"),
    }

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, CONTENT_TOP + 2)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, CONTENT_TOP + 2)
    sep:SetHeight(1)

    -- Scroll frame
    f.scrollFrame = CreateFrame("ScrollFrame", "BiddikusDKPScrollFrame", f, "FauxScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 28)
    f.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            Biddikus:UpdateDKPStandingsFrame()
        end)
    end)

    -- Create row frames
    f.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 34, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP - (i - 1) * ROW_HEIGHT)

        -- Alternating row background
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.14, 0.14, 0.14, 0.7)
        else
            row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.3)
        end

        -- Highlight on hover
        row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.05)
        row.highlight:Hide()
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self) self.highlight:Show() end)
        row:SetScript("OnLeave", function(self) self.highlight:Hide() end)

        row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rank:SetPoint("LEFT", COL.rank - 5, 0)
        row.rank:SetWidth(28)
        row.rank:SetJustifyH("LEFT")

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", COL.name - 5, 0)
        row.name:SetWidth(125)
        row.name:SetJustifyH("LEFT")

        row.class = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.class:SetPoint("LEFT", COL.class - 5, 0)
        row.class:SetWidth(95)
        row.class:SetJustifyH("LEFT")

        row.current = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.current:SetPoint("LEFT", COL.current - 5, 0)
        row.current:SetWidth(80)
        row.current:SetJustifyH("CENTER")

        row.lifetime = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.lifetime:SetPoint("LEFT", COL.lifetime - 5, 0)
        row.lifetime:SetWidth(55)
        row.lifetime:SetJustifyH("CENTER")

        row:Hide()
        f.rows[i] = row
    end

    -- Footer
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.footer:SetTextColor(0.5, 0.5, 0.5, 1)

    f.ROW_HEIGHT = ROW_HEIGHT
    f.NUM_ROWS = NUM_ROWS
    self.dkpStandingsFrame = f
end

function Biddikus:UpdateDKPStandingsFrame()
    if not self.dkpStandingsFrame or not self.dkpStandingsFrame:IsShown() then return end
    local f = self.dkpStandingsFrame

    -- Build sorted data
    local standings = self.db and self.db.profile.dkp and self.db.profile.dkp.standings or {}
    local sorted = {}
    for name, data in pairs(standings) do
        tinsert(sorted, {
            name = name,
            current = data.current,
            lifetime = data.lifetime,
            class = data.class or "",
        })
    end

    -- Sort
    local col = f.sortColumn or "current"
    local asc = f.sortAscending
    if col == "current" then
        sort(sorted, function(a, b)
            if asc then return a.current < b.current end
            return a.current > b.current
        end)
    elseif col == "lifetime" then
        sort(sorted, function(a, b)
            if asc then return a.lifetime < b.lifetime end
            return a.lifetime > b.lifetime
        end)
    elseif col == "name" then
        sort(sorted, function(a, b)
            if asc then return a.name < b.name end
            return a.name > b.name
        end)
    elseif col == "class" then
        sort(sorted, function(a, b)
            if a.class == b.class then return a.current > b.current end
            if asc then return a.class < b.class end
            return a.class > b.class
        end)
    end

    -- Update column header arrows
    local headerDisplayNames = { name = "Player", class = "Class", current = "Current", lifetime = "Lifetime" }
    for _, header in ipairs(f.headers) do
        if header.sortKey then
            local arrow = ""
            if f.sortColumn == header.sortKey then
                arrow = asc and "  |cFF888888^|r" or "  |cFF888888v|r"
            end
            header.label:SetText("|cFFFFD100" .. header.baseText .. "|r" .. arrow)
        end
    end

    -- Update scroll
    local numRows = f.NUM_ROWS
    local offset = FauxScrollFrame_GetOffset(f.scrollFrame)
    FauxScrollFrame_Update(f.scrollFrame, #sorted, numRows, f.ROW_HEIGHT)

    for i = 1, numRows do
        local row = f.rows[i]
        local idx = offset + i
        if idx <= #sorted then
            local entry = sorted[idx]
            local classHex = self:DKPGetClassColor(entry.class)

            row.rank:SetText("|cFF888888" .. idx .. ".|r")
            row.name:SetText("|cFF" .. classHex .. entry.name .. "|r")

            local classLabel = entry.class ~= "" and (entry.class:sub(1,1) .. entry.class:sub(2):lower()) or "Unknown"
            row.class:SetText("|cFF" .. classHex .. classLabel .. "|r")

            if entry.current >= 0 then
                row.current:SetText("|cFF00FF00" .. entry.current .. "|r")
            else
                row.current:SetText("|cFFFF0000" .. entry.current .. "|r")
            end

            row.lifetime:SetText("|cFFCCCCCC" .. entry.lifetime .. "|r")
            row:Show()
        else
            row:Hide()
        end
    end

    f.footer:SetText("Total players: " .. #sorted)
end

function Biddikus:ShowDKPExportCSV()
    local standings = self.db and self.db.profile.dkp and self.db.profile.dkp.standings or {}

    -- Build sorted list alphabetically by player name
    local sorted = {}
    for name, data in pairs(standings) do
        tinsert(sorted, {
            name = name,
            class = data.class or "",
            current = data.current or 0,
            lifetime = data.lifetime or 0,
        })
    end
    sort(sorted, function(a, b) return a.name < b.name end)

    -- Generate CSV
    local lines = { "Player\tClass\tCurrent DKP\tLifetime DKP" }
    for _, entry in ipairs(sorted) do
        local classLabel = entry.class ~= "" and (entry.class:sub(1,1) .. entry.class:sub(2):lower()) or "Unknown"
        tinsert(lines, format("%s\t%s\t%.2f\t%.2f", entry.name, classLabel, entry.current, entry.lifetime))
    end
    local csv = table.concat(lines, "\n")

    -- Create or reuse the export frame
    if not self.dkpExportFrame then
        local f = CreateFrame("Frame", "BiddikusDKPExport", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        f:SetSize(500, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(200)
        f:Hide()

        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
        f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Title
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.title:SetText("|cFFFFD100Export DKP Standings|r")

        -- Instructions
        f.instructions = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.instructions:SetPoint("TOPLEFT", 12, -30)
        f.instructions:SetTextColor(0.6, 0.6, 0.6, 1)
        f.instructions:SetText("Press Ctrl+A to select all, then Ctrl+C to copy.")

        -- Close button
        f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.closeBtn:SetPoint("TOPRIGHT", -2, -2)

        -- Scroll frame for the edit box
        local sf = CreateFrame("ScrollFrame", "BiddikusDKPExportScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -48)
        sf:SetPoint("BOTTOMRIGHT", -30, 10)

        local eb = CreateFrame("EditBox", "BiddikusDKPExportEditBox", sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetWidth(sf:GetWidth() or 440)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        eb:SetScript("OnCursorChanged", function(self) self:HighlightText() end)
        sf:SetScrollChild(eb)

        f.editBox = eb
        f.scrollFrame = sf
        self.dkpExportFrame = f
    end

    local f = self.dkpExportFrame
    f.editBox:SetText(csv)
    f.editBox:SetWidth(f.scrollFrame:GetWidth() or 440)
    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

function Biddikus:ShowDKPStandings()
    self:SetupDKPStandingsFrame()
    if self.dkpStandingsFrame:IsShown() then
        self.dkpStandingsFrame:Hide()
    else
        self.dkpStandingsFrame:Show()
        self:UpdateDKPStandingsFrame()
    end
end

-----------------------------
-- Loot History
-----------------------------

function Biddikus:DKPRecordLoot(player, class, amount, item)
    if not self.db or not self.db.profile.dkp then return end
    local dkp = self.db.profile.dkp
    local shortName = strmatch(player, "^([^%-]+)") or player
    -- Resolve class from standings if not provided
    local playerClass = class or ""
    if (playerClass == "" or not playerClass) and dkp.standings[shortName] then
        playerClass = dkp.standings[shortName].class or ""
    end
    tinsert(dkp.lootHistory, {
        timestamp = time(),
        player = shortName,
        class = playerClass,
        amount = amount or 0,
        item = item or "Unknown",
        raid = self._dkpCurrentRaidContext or nil,
    })
    -- Cap at 500 entries
    while #dkp.lootHistory > 500 do
        table.remove(dkp.lootHistory, 1)
    end
end

function Biddikus:SetupDKPLootFrame()
    if self.dkpLootFrame then return end

    local ROW_HEIGHT = 20
    local NUM_ROWS = 16
    local FRAME_W = 520
    local CONTENT_TOP = -82
    local FRAME_H = -CONTENT_TOP + NUM_ROWS * ROW_HEIGHT + 36
    local COL = { rank = 10, name = 40, item = 170, amount = 370, date = 440 }

    local f = CreateFrame("Frame", "BiddikusDKPLootHistory", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText("|cFFFFD100Loot History|r")

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Raid filter dropdown
    f.raidFilter = "ALL"
    f.raidDropdown = CreateFrame("Frame", "BiddikusLootRaidDropdown", f, "UIDropDownMenuTemplate")
    f.raidDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -30)
    UIDropDownMenu_SetWidth(f.raidDropdown, 130)
    UIDropDownMenu_SetText(f.raidDropdown, "All Raids")
    UIDropDownMenu_Initialize(f.raidDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Raids"
        info.func = function()
            f.raidFilter = "ALL"
            UIDropDownMenu_SetText(f.raidDropdown, "All Raids")
            Biddikus:UpdateDKPLootFrame()
        end
        info.checked = (f.raidFilter == "ALL")
        UIDropDownMenu_AddButton(info, level)
        for _, r in ipairs(Biddikus.RAID_LIST) do
            info = UIDropDownMenu_CreateInfo()
            info.text = r.name
            info.func = function()
                f.raidFilter = r.key
                UIDropDownMenu_SetText(f.raidDropdown, r.name)
                Biddikus:UpdateDKPLootFrame()
            end
            info.checked = (f.raidFilter == r.key)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Date filter dropdown
    f.dateFilter = "ALL"
    f.dropdown = CreateFrame("Frame", "BiddikusLootDateDropdown", f, "UIDropDownMenuTemplate")
    f.dropdown:SetPoint("LEFT", f.raidDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(f.dropdown, 120)
    UIDropDownMenu_SetText(f.dropdown, "All Dates")
    UIDropDownMenu_Initialize(f.dropdown, function(self, level)
        local dkp = Biddikus.db and Biddikus.db.profile.dkp
        if not dkp then return end
        local history = dkp.lootHistory or {}

        -- Collect unique dates (newest first)
        local dateSet = {}
        local dates = {}
        for _, entry in ipairs(history) do
            local d = date("%m/%d/%Y", entry.timestamp)
            if not dateSet[d] then
                dateSet[d] = true
                tinsert(dates, { text = d, ts = entry.timestamp })
            end
        end
        sort(dates, function(a, b) return a.ts > b.ts end)

        -- "All Dates" option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Dates"
        info.func = function()
            f.dateFilter = "ALL"
            UIDropDownMenu_SetText(f.dropdown, "All Dates")
            Biddikus:UpdateDKPLootFrame()
        end
        info.checked = (f.dateFilter == "ALL")
        UIDropDownMenu_AddButton(info, level)

        -- Per-date options
        for _, d in ipairs(dates) do
            info = UIDropDownMenu_CreateInfo()
            info.text = d.text
            info.func = function()
                f.dateFilter = d.text
                UIDropDownMenu_SetText(f.dropdown, d.text)
                Biddikus:UpdateDKPLootFrame()
            end
            info.checked = (f.dateFilter == d.text)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Column header background
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    headerBg:SetColorTexture(0.15, 0.15, 0.15, 1)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -58)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -58)
    headerBg:SetHeight(22)

    -- Sort state
    f.sortColumn = "date"
    f.sortAscending = false

    -- Column header factory
    local function MakeLootHeader(parent, text, x, w, sortKey, justify)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -59)
        btn:SetSize(w, 20)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if justify == "CENTER" then
            btn.label:SetPoint("CENTER", 0, 0)
            btn.label:SetJustifyH("CENTER")
        else
            btn.label:SetPoint("LEFT", 2, 0)
        end
        btn.label:SetText("|cFFFFD100" .. text .. "|r")
        btn.sortKey = sortKey
        btn.baseText = text
        if sortKey then
            btn:SetScript("OnClick", function()
                if parent.sortColumn == sortKey then
                    parent.sortAscending = not parent.sortAscending
                else
                    parent.sortColumn = sortKey
                    parent.sortAscending = (sortKey == "name" or sortKey == "item")
                end
                Biddikus:UpdateDKPLootFrame()
            end)
            btn:SetScript("OnEnter", function(self)
                self.label:SetText("|cFFFFFFFF" .. self.baseText .. "|r")
            end)
            btn:SetScript("OnLeave", function(self)
                local arrow = ""
                if parent.sortColumn == self.sortKey then
                    arrow = parent.sortAscending and "  |cFF888888^|r" or "  |cFF888888v|r"
                end
                self.label:SetText("|cFFFFD100" .. self.baseText .. "|r" .. arrow)
            end)
        end
        return btn
    end

    f.headers = {
        MakeLootHeader(f, "#", COL.rank, 28, nil),
        MakeLootHeader(f, "Player", COL.name, 125, "name"),
        MakeLootHeader(f, "Item Won", COL.item, 195, "item"),
        MakeLootHeader(f, "DKP", COL.amount, 65, "amount", "CENTER"),
        MakeLootHeader(f, "Date", COL.date, 70, "date"),
    }

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, CONTENT_TOP + 2)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, CONTENT_TOP + 2)
    sep:SetHeight(1)

    -- Scroll frame
    f.scrollFrame = CreateFrame("ScrollFrame", "BiddikusLootScrollFrame", f, "FauxScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 28)
    f.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            Biddikus:UpdateDKPLootFrame()
        end)
    end)

    -- Create row frames
    f.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 34, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP - (i - 1) * ROW_HEIGHT)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.14, 0.14, 0.14, 0.7)
        else
            row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.3)
        end

        row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.05)
        row.highlight:Hide()
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
            -- Show item tooltip
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)

        row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rank:SetPoint("LEFT", COL.rank - 5, 0)
        row.rank:SetWidth(28)
        row.rank:SetJustifyH("LEFT")

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", COL.name - 5, 0)
        row.name:SetWidth(125)
        row.name:SetJustifyH("LEFT")

        row.item = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.item:SetPoint("LEFT", COL.item - 5, 0)
        row.item:SetWidth(195)
        row.item:SetJustifyH("LEFT")

        row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.amount:SetPoint("LEFT", COL.amount - 5, 0)
        row.amount:SetWidth(65)
        row.amount:SetJustifyH("CENTER")

        row.date = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.date:SetPoint("LEFT", COL.date - 5, 0)
        row.date:SetWidth(70)
        row.date:SetJustifyH("LEFT")

        row:Hide()
        f.rows[i] = row
    end

    -- Footer
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.footer:SetTextColor(0.5, 0.5, 0.5, 1)

    f.ROW_HEIGHT = ROW_HEIGHT
    f.NUM_ROWS = NUM_ROWS
    self.dkpLootFrame = f
end

function Biddikus:UpdateDKPLootFrame()
    if not self.dkpLootFrame or not self.dkpLootFrame:IsShown() then return end
    local f = self.dkpLootFrame

    local dkp = self.db and self.db.profile.dkp
    local history = dkp and dkp.lootHistory or {}

    -- Filter by date and raid tag
    local filtered = {}
    for _, entry in ipairs(history) do
        local passDate = true
        local passRaid = true
        if f.dateFilter ~= "ALL" then
            local d = date("%m/%d/%Y", entry.timestamp)
            if d ~= f.dateFilter then passDate = false end
        end
        if f.raidFilter and f.raidFilter ~= "ALL" then
            if (entry.raid or "") ~= f.raidFilter then passRaid = false end
        end
        if passDate and passRaid then
            tinsert(filtered, entry)
        end
    end

    -- Sort
    local col = f.sortColumn or "date"
    local asc = f.sortAscending
    if col == "date" then
        sort(filtered, function(a, b)
            if asc then return a.timestamp < b.timestamp end
            return a.timestamp > b.timestamp
        end)
    elseif col == "name" then
        sort(filtered, function(a, b)
            if asc then return a.player < b.player end
            return a.player > b.player
        end)
    elseif col == "amount" then
        sort(filtered, function(a, b)
            if asc then return a.amount < b.amount end
            return a.amount > b.amount
        end)
    elseif col == "item" then
        -- Sort by item name (strip color codes for comparison)
        sort(filtered, function(a, b)
            local nameA = (a.item or ""):match("%[(.-)%]") or a.item or ""
            local nameB = (b.item or ""):match("%[(.-)%]") or b.item or ""
            if asc then return nameA < nameB end
            return nameA > nameB
        end)
    end

    -- Update column header arrows
    for _, header in ipairs(f.headers) do
        if header.sortKey then
            local arrow = ""
            if f.sortColumn == header.sortKey then
                arrow = asc and "  |cFF888888^|r" or "  |cFF888888v|r"
            end
            header.label:SetText("|cFFFFD100" .. header.baseText .. "|r" .. arrow)
        end
    end

    -- Update scroll
    local numRows = f.NUM_ROWS
    local offset = FauxScrollFrame_GetOffset(f.scrollFrame)
    FauxScrollFrame_Update(f.scrollFrame, #filtered, numRows, f.ROW_HEIGHT)

    for i = 1, numRows do
        local row = f.rows[i]
        local idx = offset + i
        if idx <= #filtered then
            local entry = filtered[idx]
            local classHex = self:DKPGetClassColor(entry.class)

            row.rank:SetText("|cFF888888" .. idx .. ".|r")
            row.name:SetText("|cFF" .. classHex .. entry.player .. "|r")

            -- Display item - use the stored link which includes color
            local itemDisplay = entry.item or "Unknown"
            -- Try to get just the item name for display
            local itemName = itemDisplay:match("%[(.-)%]")
            if itemName then
                -- Get item quality color from the link
                local qualityColor = itemDisplay:match("|c(%x+)")
                if qualityColor then
                    row.item:SetText("|c" .. qualityColor .. itemName .. "|r")
                else
                    row.item:SetText(itemName)
                end
            else
                row.item:SetText(itemDisplay)
            end
            row.itemLink = entry.item

            row.amount:SetText("|cFFFF8800" .. format("%.1f", entry.amount) .. "|r")
            row.date:SetText("|cFFAAAAAA" .. date("%m/%d %H:%M", entry.timestamp) .. "|r")

            row:Show()
        else
            row:Hide()
        end
    end

    local filterParts = {}
    if f.raidFilter and f.raidFilter ~= "ALL" then
        tinsert(filterParts, Biddikus.RAID_KEYS[f.raidFilter] or f.raidFilter)
    end
    if f.dateFilter ~= "ALL" then
        tinsert(filterParts, f.dateFilter)
    end
    local filterLabel = #filterParts > 0 and (" — " .. table.concat(filterParts, ", ")) or ""
    f.footer:SetText(#filtered .. " items" .. filterLabel)
end

function Biddikus:ShowDKPLootHistory()
    self:SetupDKPLootFrame()
    if self.dkpLootFrame:IsShown() then
        self.dkpLootFrame:Hide()
    else
        self.dkpLootFrame:Show()
        self:UpdateDKPLootFrame()
    end
end

-----------------------------
-- Personal Transaction History
-----------------------------

function Biddikus:SetupDKPPersonalFrame()
    if self.dkpPersonalFrame then return end

    local ROW_HEIGHT = 20
    local NUM_ROWS = 16
    local FRAME_W = 490
    local CONTENT_TOP = -58
    local FRAME_H = -CONTENT_TOP + NUM_ROWS * ROW_HEIGHT + 36
    local COL = { rank = 10, date = 38, typecol = 118, amount = 188, item = 248, raid = 408 }

    local f = CreateFrame("Frame", "BiddikusDKPPersonalHistory", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER", UIParent, "CENTER", -50, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText("|cFFFFD100My Transaction History|r")

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Column header background
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    headerBg:SetColorTexture(0.15, 0.15, 0.15, 1)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -34)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -34)
    headerBg:SetHeight(22)

    -- Sort state
    f.sortColumn = "date"
    f.sortAscending = false

    -- Column header factory
    local function MakePersonalHeader(parent, text, x, w, sortKey, justify)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -35)
        btn:SetSize(w, 20)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if justify == "CENTER" then
            btn.label:SetPoint("CENTER", 0, 0)
            btn.label:SetJustifyH("CENTER")
        else
            btn.label:SetPoint("LEFT", 2, 0)
        end
        btn.label:SetText("|cFFFFD100" .. text .. "|r")
        btn.sortKey = sortKey
        btn.baseText = text
        if sortKey then
            btn:SetScript("OnClick", function()
                if parent.sortColumn == sortKey then
                    parent.sortAscending = not parent.sortAscending
                else
                    parent.sortColumn = sortKey
                    parent.sortAscending = (sortKey == "item" or sortKey == "raid" or sortKey == "typecol")
                end
                Biddikus:UpdateDKPPersonalFrame()
            end)
            btn:SetScript("OnEnter", function(self)
                self.label:SetText("|cFFFFFFFF" .. self.baseText .. "|r")
            end)
            btn:SetScript("OnLeave", function(self)
                local arrow = ""
                if parent.sortColumn == self.sortKey then
                    arrow = parent.sortAscending and "  |cFF888888^|r" or "  |cFF888888v|r"
                end
                self.label:SetText("|cFFFFD100" .. self.baseText .. "|r" .. arrow)
            end)
        end
        return btn
    end

    f.headers = {
        MakePersonalHeader(f, "#", COL.rank, 26, nil),
        MakePersonalHeader(f, "Date", COL.date, 78, "date"),
        MakePersonalHeader(f, "Type", COL.typecol, 68, "typecol"),
        MakePersonalHeader(f, "Amount", COL.amount, 58, "amount", "CENTER"),
        MakePersonalHeader(f, "Item", COL.item, 155, "item"),
        MakePersonalHeader(f, "Raid", COL.raid, 78, "raid"),
    }

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, CONTENT_TOP + 2)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, CONTENT_TOP + 2)
    sep:SetHeight(1)

    -- Scroll frame
    f.scrollFrame = CreateFrame("ScrollFrame", "BiddikusPersonalScrollFrame", f, "FauxScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 28)
    f.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            Biddikus:UpdateDKPPersonalFrame()
        end)
    end)

    -- Create row frames
    f.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 34, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 5, CONTENT_TOP - (i - 1) * ROW_HEIGHT)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.14, 0.14, 0.14, 0.7)
        else
            row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.3)
        end

        row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.05)
        row.highlight:Hide()
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)

        row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rank:SetPoint("LEFT", COL.rank - 5, 0)
        row.rank:SetWidth(26)
        row.rank:SetJustifyH("LEFT")

        row.date = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.date:SetPoint("LEFT", COL.date - 5, 0)
        row.date:SetWidth(78)
        row.date:SetJustifyH("LEFT")

        row.typecol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.typecol:SetPoint("LEFT", COL.typecol - 5, 0)
        row.typecol:SetWidth(68)
        row.typecol:SetJustifyH("LEFT")

        row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.amount:SetPoint("LEFT", COL.amount - 5, 0)
        row.amount:SetWidth(58)
        row.amount:SetJustifyH("CENTER")

        row.item = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.item:SetPoint("LEFT", COL.item - 5, 0)
        row.item:SetWidth(155)
        row.item:SetJustifyH("LEFT")

        row.raid = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.raid:SetPoint("LEFT", COL.raid - 5, 0)
        row.raid:SetWidth(78)
        row.raid:SetJustifyH("LEFT")

        row:Hide()
        f.rows[i] = row
    end

    -- Footer
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.footer:SetTextColor(0.5, 0.5, 0.5, 1)

    f.ROW_HEIGHT = ROW_HEIGHT
    f.NUM_ROWS = NUM_ROWS
    self.dkpPersonalFrame = f
end

function Biddikus:UpdateDKPPersonalFrame()
    if not self.dkpPersonalFrame or not self.dkpPersonalFrame:IsShown() then return end
    local f = self.dkpPersonalFrame

    local dkp = self.db and self.db.profile.dkp
    if not dkp then return end

    local playerName = self.playerName
    local log = dkp.log or {}
    local lootHistory = dkp.lootHistory or {}

    -- Build loot history lookup for raid tags (match by player + timestamp within 10 sec)
    local lootLookup = {}
    for _, entry in ipairs(lootHistory) do
        if entry.player == playerName then
            lootLookup[entry.timestamp] = entry.raid or nil
        end
    end

    -- Build combined personal entries
    local entries = {}
    for _, entry in ipairs(log) do
        local include = false
        local entryType = entry.action
        local raidTag = nil

        -- Check entry.raid field first (boss kill entries store it directly)
        if entry.raid then
            raidTag = entry.raid
        end

        if entry.action == "DEDUCT" and entry.player == playerName then
            include = true
            -- Try to find raid tag from loot history if not on the log entry
            if not raidTag then
                for ts, raid in pairs(lootLookup) do
                    if math.abs(ts - (entry.timestamp or 0)) <= 10 then
                        raidTag = raid
                        break
                    end
                end
            end
        elseif entry.action == "ADJUST" and entry.player == playerName then
            include = true
        elseif entry.action == "AWARD" then
            include = true
        elseif entry.action == "DECAY" then
            include = true
        elseif entry.action == "BOSS_KILL" then
            include = true
        elseif entry.action == "FIRST_KILL" then
            include = true
        end

        if include then
            -- Get display name for item
            local itemDisplay = ""
            local itemLink = nil
            if entry.item and entry.item ~= "" then
                local itemName = entry.item:match("%[(.-)%]")
                local qualityColor = entry.item:match("|c(%x+)")
                if itemName then
                    itemDisplay = qualityColor and ("|c" .. qualityColor .. itemName .. "|r") or itemName
                    itemLink = entry.item
                else
                    itemDisplay = entry.item
                end
            end

            -- Type display name and color
            local typeColor, typeDisplay
            if entryType == "AWARD" then typeColor = "00FF00"; typeDisplay = "Award"
            elseif entryType == "DEDUCT" then typeColor = "FF8800"; typeDisplay = "Deduct"
            elseif entryType == "DECAY" then typeColor = "FF4444"; typeDisplay = "Decay"
            elseif entryType == "ADJUST" then typeColor = "44AAFF"; typeDisplay = "Adjust"
            elseif entryType == "BOSS_KILL" then typeColor = "FFD100"; typeDisplay = "Boss Kill"
            elseif entryType == "FIRST_KILL" then typeColor = "FF00FF"; typeDisplay = "First Kill"
            else typeColor = "AAAAAA"; typeDisplay = entryType
            end

            tinsert(entries, {
                timestamp = entry.timestamp or 0,
                typecol = typeDisplay,
                typeColor = typeColor,
                amount = entry.amount or 0,
                itemDisplay = itemDisplay,
                itemLink = itemLink,
                itemSort = (entry.item or ""):match("%[(.-)%]") or entry.item or "",
                raid = raidTag or "",
                raidDisplay = raidTag and (Biddikus.RAID_KEYS[raidTag] or raidTag) or "",
                note = entry.note or "",
            })
        end
    end

    -- Sort
    local col = f.sortColumn or "date"
    local asc = f.sortAscending
    if col == "date" then
        sort(entries, function(a, b)
            if asc then return a.timestamp < b.timestamp end
            return a.timestamp > b.timestamp
        end)
    elseif col == "typecol" then
        sort(entries, function(a, b)
            if a.typecol == b.typecol then return a.timestamp > b.timestamp end
            if asc then return a.typecol < b.typecol end
            return a.typecol > b.typecol
        end)
    elseif col == "amount" then
        sort(entries, function(a, b)
            if asc then return a.amount < b.amount end
            return a.amount > b.amount
        end)
    elseif col == "item" then
        sort(entries, function(a, b)
            if a.itemSort == b.itemSort then return a.timestamp > b.timestamp end
            if asc then return a.itemSort < b.itemSort end
            return a.itemSort > b.itemSort
        end)
    elseif col == "raid" then
        sort(entries, function(a, b)
            if a.raid == b.raid then return a.timestamp > b.timestamp end
            if asc then return a.raid < b.raid end
            return a.raid > b.raid
        end)
    end

    -- Update column header arrows
    for _, header in ipairs(f.headers) do
        if header.sortKey then
            local arrow = ""
            if f.sortColumn == header.sortKey then
                arrow = asc and "  |cFF888888^|r" or "  |cFF888888v|r"
            end
            header.label:SetText("|cFFFFD100" .. header.baseText .. "|r" .. arrow)
        end
    end

    -- Update scroll
    local numRows = f.NUM_ROWS
    local offset = FauxScrollFrame_GetOffset(f.scrollFrame)
    FauxScrollFrame_Update(f.scrollFrame, #entries, numRows, f.ROW_HEIGHT)

    for i = 1, numRows do
        local row = f.rows[i]
        local idx = offset + i
        if idx <= #entries then
            local e = entries[idx]

            row.rank:SetText("|cFF888888" .. idx .. ".|r")
            row.date:SetText("|cFFAAAAAA" .. date("%m/%d %H:%M", e.timestamp) .. "|r")
            row.typecol:SetText("|cFF" .. e.typeColor .. e.typecol .. "|r")

            if e.amount >= 0 then
                row.amount:SetText("|cFF00FF00+" .. e.amount .. "|r")
            else
                row.amount:SetText("|cFFFF0000" .. e.amount .. "|r")
            end

            row.item:SetText(e.itemDisplay)
            row.itemLink = e.itemLink
            row.raid:SetText("|cFFCCCCCC" .. e.raidDisplay .. "|r")

            row:Show()
        else
            row:Hide()
        end
    end

    f.footer:SetText(#entries .. " transactions for " .. (playerName or "???"))
end

function Biddikus:ShowDKPPersonalHistory()
    self:SetupDKPPersonalFrame()
    if self.dkpPersonalFrame:IsShown() then
        self.dkpPersonalFrame:Hide()
    else
        self.dkpPersonalFrame:Show()
        self:UpdateDKPPersonalFrame()
    end
end

function Biddikus:DKPGetLogText()
    if not self.db or not self.db.profile.dkp then return "|cFFAAAAAANo log data.|r" end
    local log = self.db.profile.dkp.log
    if #log == 0 then
        return "|cFFAAAAAANo log entries.|r"
    end
    local lines = {}
    local count = 0
    for i = #log, 1, -1 do
        if count >= 50 then break end
        local entry = log[i]
        local ts = entry.timestamp and date("%m/%d %H:%M", entry.timestamp) or "???"
        local actionDisplay = entry.action
        if actionDisplay == "BOSS_KILL" then actionDisplay = "Boss Kill"
        elseif actionDisplay == "FIRST_KILL" then actionDisplay = "First Kill"
        end
        local line = format("[%s] %s: %s %+d", ts, actionDisplay, entry.player or "RAID", entry.amount or 0)
        if entry.item then
            line = line .. " (" .. entry.item .. ")"
        end
        if entry.note and entry.note ~= "" then
            line = line .. " - " .. entry.note
        end
        if entry.officer then
            line = line .. " [by " .. entry.officer .. "]"
        end
        tinsert(lines, line)
        count = count + 1
    end
    return table.concat(lines, "\n")
end

function Biddikus:DKPAddLogEntry(action, player, amount, item, note, raid)
    if not self.db or not self.db.profile.dkp then return end
    local dkp = self.db.profile.dkp
    local entry = {
        timestamp = time(),
        action = action,
        officer = self.playerName,
        player = player,
        amount = amount,
        item = item,
        note = note,
        raid = raid or nil,
        version = dkp.syncVersion,
    }
    tinsert(dkp.log, entry)
    -- Cap log at 200 entries
    while #dkp.log > 200 do
        table.remove(dkp.log, 1)
    end
end

function Biddikus:DKPCompileRaid()
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    if not IsInRaid() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a raid.")
        return
    end
    local dkp = self.db.profile.dkp
    local added = 0
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
        if name then
            -- Strip realm name if present
            local shortName = strmatch(name, "^([^%-]+)")
            if shortName then
                if not dkp.standings[shortName] then
                    dkp.standings[shortName] = { current = dkp.defaultAmount, lifetime = 0, class = fileName or "" }
                    added = added + 1
                elseif fileName and (not dkp.standings[shortName].class or dkp.standings[shortName].class == "") then
                    -- Backfill class for existing entries missing it
                    dkp.standings[shortName].class = fileName
                end
            end
        end
    end
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("COMPILE", nil, dkp.defaultAmount, nil, "Compiled raid roster, " .. added .. " new members")
    print("|cFF00FF00[Biddikus DKP]|r Raid compiled. " .. added .. " new members added with " .. dkp.defaultAmount .. " starting DKP.")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPAwardRaid(amount, note)
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    if not IsInRaid() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a raid.")
        return
    end
    local dkp = self.db.profile.dkp
    local awarded = 0
    -- Build set of current raid members
    local raidMembers = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            local shortName = strmatch(name, "^([^%-]+)")
            if shortName then
                raidMembers[shortName] = true
            end
        end
    end
    for name, data in pairs(dkp.standings) do
        if raidMembers[name] then
            data.current = data.current + amount
            if amount > 0 then
                data.lifetime = data.lifetime + amount
            end
            awarded = awarded + 1
        end
    end
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("AWARD", "RAID", amount, nil, (note ~= "" and note or "Raid award") .. " (" .. awarded .. " members)")
    print("|cFF00FF00[Biddikus DKP]|r Awarded " .. amount .. " DKP to " .. awarded .. " raid members.")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPBossKillAward()
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    if not IsInRaid() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a raid.")
        return
    end
    local raidKey = self._dkpCurrentRaidContext
    if not raidKey then
        print("|cFFFF0000[Biddikus DKP]|r Select a raid first.")
        return
    end
    local dkp = self.db.profile.dkp
    local amount = dkp.bossKillAmounts and dkp.bossKillAmounts[raidKey] or 0
    if amount <= 0 then
        print("|cFFFF0000[Biddikus DKP]|r Boss kill EKP for this raid is set to 0.")
        return
    end
    local raidName = self.RAID_KEYS[raidKey] or raidKey
    local awarded = 0
    local raidMembers = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            local shortName = strmatch(name, "^([^%-]+)")
            if shortName then raidMembers[shortName] = true end
        end
    end
    for name, data in pairs(dkp.standings) do
        if raidMembers[name] then
            data.current = data.current + amount
            data.lifetime = data.lifetime + amount
            awarded = awarded + 1
        end
    end
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("BOSS_KILL", "RAID", amount, nil, raidName .. " Boss Kill (" .. awarded .. " members)", raidKey)
    print("|cFF00FF00[Biddikus DKP]|r Boss Kill: Awarded " .. amount .. " EKP to " .. awarded .. " raid members (" .. raidName .. ").")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPFirstKillAward()
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    if not IsInRaid() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a raid.")
        return
    end
    local raidKey = self._dkpCurrentRaidContext
    if not raidKey then
        print("|cFFFF0000[Biddikus DKP]|r Select a raid first.")
        return
    end
    local dkp = self.db.profile.dkp
    local bossAmount = dkp.bossKillAmounts and dkp.bossKillAmounts[raidKey] or 0
    local firstBonus = dkp.firstKillAmount or 5
    local totalAmount = bossAmount + firstBonus
    if totalAmount <= 0 then
        print("|cFFFF0000[Biddikus DKP]|r Total first kill EKP is 0.")
        return
    end
    local raidName = self.RAID_KEYS[raidKey] or raidKey
    local awarded = 0
    local raidMembers = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            local shortName = strmatch(name, "^([^%-]+)")
            if shortName then raidMembers[shortName] = true end
        end
    end
    for name, data in pairs(dkp.standings) do
        if raidMembers[name] then
            data.current = data.current + totalAmount
            data.lifetime = data.lifetime + totalAmount
            awarded = awarded + 1
        end
    end
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("FIRST_KILL", "RAID", totalAmount, nil, raidName .. " First Kill (Kill: " .. bossAmount .. " + Bonus: " .. firstBonus .. ") (" .. awarded .. " members)", raidKey)
    print("|cFF00FF00[Biddikus DKP]|r First Kill: Awarded " .. totalAmount .. " EKP to " .. awarded .. " raid members (" .. raidName .. ": " .. bossAmount .. " + " .. firstBonus .. " bonus).")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPAdjustPlayer(player, amount, note)
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    local dkp = self.db.profile.dkp
    if not dkp.standings[player] then
        dkp.standings[player] = { current = 0, lifetime = 0, class = "" }
    end
    dkp.standings[player].current = dkp.standings[player].current + amount
    if amount > 0 then
        dkp.standings[player].lifetime = dkp.standings[player].lifetime + amount
    end
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("ADJUST", player, amount, nil, note ~= "" and note or "Manual adjustment")
    print("|cFF00FF00[Biddikus DKP]|r Adjusted " .. player .. " by " .. amount .. " DKP. New balance: " .. dkp.standings[player].current)
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPAutoDeduct(player, amount, item)
    if not self:IsDKPOfficer() then return end
    local dkp = self.db.profile.dkp
    -- Strip realm name if present
    local shortName = strmatch(player, "^([^%-]+)") or player
    if not dkp.standings[shortName] then
        dkp.standings[shortName] = { current = 0, lifetime = 0, class = "" }
    end
    dkp.standings[shortName].current = dkp.standings[shortName].current - amount
    dkp.syncVersion = dkp.syncVersion + 1
    local itemStr = item or "Unknown Item"
    self:DKPAddLogEntry("DEDUCT", shortName, -amount, itemStr, "Bid winner auto-deduct")
    print("|cFF00FF00[Biddikus DKP]|r Auto-deducted " .. format("%.2f", amount) .. " DKP from " .. shortName .. " for " .. itemStr)
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPBroadcastFull(channel)
    if not self:IsDKPOfficer() then return end
    channel = channel or "RAID"
    if channel == "RAID" and not IsInRaid() then return end
    if channel == "GUILD" and not IsInGuild() then return end
    local dkp = self.db.profile.dkp
    dkp.lastSyncTimestamp = time()
    local payload = {
        messageType = "DKP_FULL_SYNC",
        syncVersion = dkp.syncVersion,
        standings = dkp.standings,
        log = dkp.log,
        lootHistory = dkp.lootHistory,
        lastDecayDate = dkp.lastDecayDate,
        bossKillAmounts = dkp.bossKillAmounts,
        firstKillAmount = dkp.firstKillAmount,
        secondPricePlusOne = dkp.secondPricePlusOne,
        timestamp = dkp.lastSyncTimestamp,
    }
    self:SendComm(payload, channel)
    local channelName = channel == "GUILD" and "guild" or "raid"
    print("|cFF00FF00[Biddikus DKP]|r Broadcast DKP data to " .. channelName .. " (version " .. dkp.syncVersion .. ").")
    LibStub("AceConfigRegistry-3.0"):NotifyChange("Biddikus_Continued")
    self:UpdateDKPStandingsFrame()
    self:UpdateDKPLootFrame()
end

function Biddikus:DKPRequestSync()
    if not IsInRaid() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a raid to request sync.")
        return
    end
    local payload = {
        messageType = "DKP_REQUEST_SYNC",
        playerName = self.playerName,
    }
    self:SendComm(payload)
    print("|cFF00FF00[Biddikus DKP]|r Sync requested from officers in raid.")
end

function Biddikus:DKPRequestGuildSync()
    if not IsInGuild() then
        print("|cFFFF0000[Biddikus DKP]|r You must be in a guild to request guild sync.")
        return
    end
    local payload = {
        messageType = "DKP_REQUEST_SYNC",
        playerName = self.playerName,
    }
    self:SendComm(payload, "GUILD")
    print("|cFF00FF00[Biddikus DKP]|r Sync requested from officers in guild.")
end

Biddikus._dkpLastSyncResponse = 0

function Biddikus:DKPHandleSyncRequest(sender, channel)
    if not self:IsDKPOfficer() then return end
    channel = channel or "RAID"
    -- 5-second throttle
    local now = GetTime()
    if now - Biddikus._dkpLastSyncResponse < 5 then return end
    Biddikus._dkpLastSyncResponse = now
    self:DKPBroadcastFull(channel)
end

function Biddikus:DKPReceiveFullSync(payload, sender)
    if not self.db or not self.db.profile.dkp then return end
    local dkp = self.db.profile.dkp
    local incomingVersion = payload.syncVersion or 0
    -- Accept if incoming version >= local version
    if incomingVersion < dkp.syncVersion then
        return
    end
    -- Update standings
    dkp.standings = payload.standings or dkp.standings
    dkp.syncVersion = incomingVersion
    dkp.lastSyncTimestamp = payload.timestamp or time()
    -- Replace log, loot history, and decay date
    dkp.log = payload.log or dkp.log
    dkp.lootHistory = payload.lootHistory or dkp.lootHistory
    if payload.lastDecayDate and payload.lastDecayDate > (dkp.lastDecayDate or "") then
        dkp.lastDecayDate = payload.lastDecayDate
    end
    -- Sync boss kill settings
    if payload.bossKillAmounts then
        dkp.bossKillAmounts = payload.bossKillAmounts
    end
    if payload.firstKillAmount then
        dkp.firstKillAmount = payload.firstKillAmount
    end
    if payload.secondPricePlusOne ~= nil then
        dkp.secondPricePlusOne = payload.secondPricePlusOne
    end
    print("|cFF00FF00[Biddikus DKP]|r Received DKP sync from " .. sender .. " (version " .. incomingVersion .. ").")
    self:DKPUpdateBalanceDisplay()
    LibStub("AceConfigRegistry-3.0"):NotifyChange("Biddikus_Continued")
    self:UpdateDKPStandingsFrame()
end

function Biddikus:DKPResetAll()
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    local dkp = self.db.profile.dkp
    wipe(dkp.standings)
    wipe(dkp.log)
    wipe(dkp.lootHistory)
    dkp.lastDecayDate = ""
    dkp.syncVersion = dkp.syncVersion + 1
    dkp.lastSyncTimestamp = time()
    self:DKPAddLogEntry("RESET", nil, 0, nil, "All DKP reset")
    print("|cFF00FF00[Biddikus DKP]|r All DKP data has been reset.")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPGetLastTuesday()
    local now = time()
    local t = date("*t", now)
    -- wday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    local daysSinceTuesday = (t.wday - 3) % 7
    local lastTuesday = now - daysSinceTuesday * 86400
    return date("%Y-%m-%d", lastTuesday)
end

function Biddikus:DKPIsDecayOverdue()
    if not self.db or not self.db.profile.dkp then return false end
    local lastDecay = self.db.profile.dkp.lastDecayDate
    if lastDecay == "" then return true end
    local lastTuesday = self:DKPGetLastTuesday()
    return lastDecay < lastTuesday
end

function Biddikus:DKPApplyDecay()
    if not self:IsDKPOfficer() then
        print("|cFFFF0000[Biddikus DKP]|r You are not a DKP officer.")
        return
    end
    local dkp = self.db.profile.dkp
    local decayed = 0
    for name, data in pairs(dkp.standings) do
        if data.current > 0 then
            local loss = floor(data.current * 0.1)
            if loss < 1 then loss = 1 end
            data.current = data.current - loss
            decayed = decayed + 1
        end
    end
    dkp.lastDecayDate = date("%Y-%m-%d")
    dkp.syncVersion = dkp.syncVersion + 1
    self:DKPAddLogEntry("DECAY", "ALL", -10, nil, "Weekly 10% decay (" .. decayed .. " players affected)")
    print("|cFF00FF00[Biddikus DKP]|r 10% decay applied to " .. decayed .. " players.")
    self:DKPBroadcastFull()
    self:DKPUpdateBalanceDisplay()
end

function Biddikus:DKPCheckDecayOnLogin()
    if not self:IsDKPOfficer() then return end
    if self:DKPIsDecayOverdue() then
        print("|cFFFF8800[Biddikus DKP] WARNING:|r Weekly 10% decay is overdue! Open /biddikus > DKP to apply it.")
    end
end

function Biddikus:DKPBroadcastRaidContext()
    if not IsInRaid() then return end
    local payload = {
        messageType = "DKP_SET_RAID",
        raidKey = self._dkpCurrentRaidContext,
    }
    self:SendComm(payload)
    local raidName = self._dkpCurrentRaidContext and (self.RAID_KEYS[self._dkpCurrentRaidContext] or self._dkpCurrentRaidContext) or "None"
    print("|cFF00FF00[Biddikus DKP]|r Raid context set to: " .. raidName)
end

function Biddikus:DKPUpdateBalanceDisplay()
    if not self.frame or not self.frame.header or not self.frame.header.dkpText then return end
    if not self.db or not self.db.profile.dkp then
        self.frame.header.dkpText:SetText("")
        return
    end
    local dkp = self.db.profile.dkp
    local data = dkp.standings[self.playerName]
    if data then
        local current = data.current
        if current >= 0 then
            self.frame.header.dkpText:SetTextColor(0, 1, 0, 1)
        else
            self.frame.header.dkpText:SetTextColor(1, 0, 0, 1)
        end
        self.frame.header.dkpText:SetText(current .. " DKP")
    else
        self.frame.header.dkpText:SetTextColor(0.7, 0.7, 0.7, 1)
        self.frame.header.dkpText:SetText("-- DKP")
    end
end

-- Shift click item in bag
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick",function(self,button)
    local bag,slot=self:GetParent():GetID(),self:GetID();
    item = (C_Container and C_Container.GetContainerItemLink or GetContainerItemLink)(bag, slot)
    Biddikus.item = item
    Biddikus:UpdateFrame()
end);
