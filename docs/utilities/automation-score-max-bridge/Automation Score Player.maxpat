{
    "patcher": {
        "fileversion": 1,
        "appversion": {
            "major": 9,
            "minor": 1,
            "revision": 4,
            "architecture": "x64",
            "modernui": 1
        },
        "classnamespace": "box",
        "rect": [ 120.0, 120.0, 900.0, 620.0 ],
        "boxes": [
            {
                "box": {
                    "fontsize": 14.0,
                    "id": "title",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 28.0, 24.0, 330.0, 22.0 ],
                    "text": "s3g-mc Automation Score Player"
                }
            },
            {
                "box": {
                    "id": "desc",
                    "linecount": 2,
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 28.0, 50.0, 760.0, 33.0 ],
                    "text": "Drop an Automation Score JSON export here. The v8 script reads breakpoint lanes and outputs interpolated lane values, section changes, and playback metadata."
                }
            },
            {
                "box": {
                    "id": "drop",
                    "maxclass": "dropfile",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 28.0, 102.0, 180.0, 54.0 ]
                }
            },
            {
                "box": {
                    "id": "readmsg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 225.0, 119.0, 156.0, 22.0 ],
                    "text": "read $1"
                }
            },
            {
                "box": {
                    "id": "toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 28.0, 189.0, 24.0, 24.0 ]
                }
            },
            {
                "box": {
                    "id": "metro",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "bang" ],
                    "patching_rect": [ 64.0, 190.0, 78.0, 22.0 ],
                    "text": "qmetro 33"
                }
            },
            {
                "box": {
                    "id": "tickmsg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 158.0, 190.0, 46.0, 22.0 ],
                    "text": "tick"
                }
            },
            {
                "box": {
                    "id": "play",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 28.0, 238.0, 45.0, 22.0 ],
                    "text": "play"
                }
            },
            {
                "box": {
                    "id": "stop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 84.0, 238.0, 45.0, 22.0 ],
                    "text": "stop"
                }
            },
            {
                "box": {
                    "id": "reset",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 140.0, 238.0, 54.0, 22.0 ],
                    "text": "reset"
                }
            },
            {
                "box": {
                    "id": "loop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 28.0, 280.0, 132.0, 22.0 ],
                    "text": "playbackmode loop"
                }
            },
            {
                "box": {
                    "id": "pal",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 170.0, 280.0, 176.0, 22.0 ],
                    "text": "playbackmode palindrome"
                }
            },
            {
                "box": {
                    "id": "once",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 356.0, 280.0, 138.0, 22.0 ],
                    "text": "playbackmode once"
                }
            },
            {
                "box": {
                    "id": "generic",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 28.0, 322.0, 96.0, 22.0 ],
                    "text": "mode generic"
                }
            },
            {
                "box": {
                    "id": "value",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 134.0, 322.0, 84.0, 22.0 ],
                    "text": "mode value"
                }
            },
            {
                "box": {
                    "id": "cc",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 228.0, 322.0, 68.0, 22.0 ],
                    "text": "mode cc"
                }
            },
            {
                "box": {
                    "id": "laneall",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 28.0, 364.0, 68.0, 22.0 ],
                    "text": "lane all"
                }
            },
            {
                "box": {
                    "id": "laneone",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 106.0, 364.0, 58.0, 22.0 ],
                    "text": "lane 1"
                }
            },
            {
                "box": {
                    "filename": "automation_score_player_v8.js",
                    "id": "v8",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 4,
                    "outlettype": [ "", "", "", "" ],
                    "patching_rect": [ 420.0, 178.0, 214.0, 22.0 ],
                    "saved_object_attributes": {
                        "parameter_enable": 0
                    },
                    "text": "v8 automation_score_player_v8.js",
                    "textfile": {
                        "filename": "automation_score_player_v8.js",
                        "flags": 0,
                        "embed": 0,
                        "autowatch": 1
                    }
                }
            },
            {
                "box": {
                    "id": "lanegate_toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 690.0, 150.0, 20.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "lanegate",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 690.0, 178.0, 40.0, 22.0 ],
                    "text": "gate"
                }
            },
            {
                "box": {
                    "id": "laneprint",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 690.0, 212.0, 174.0, 22.0 ],
                    "text": "print automation_score_lane"
                }
            },
            {
                "box": {
                    "id": "clockgate_toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 690.0, 254.0, 20.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "clockgate",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 690.0, 282.0, 40.0, 22.0 ],
                    "text": "gate"
                }
            },
            {
                "box": {
                    "id": "clockprint",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 690.0, 316.0, 184.0, 22.0 ],
                    "text": "print automation_score_clock"
                }
            },
            {
                "box": {
                    "id": "metagate_toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 690.0, 358.0, 20.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "metagate",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 690.0, 386.0, 40.0, 22.0 ],
                    "text": "gate"
                }
            },
            {
                "box": {
                    "id": "metaprint",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 690.0, 420.0, 180.0, 22.0 ],
                    "text": "print automation_score_meta"
                }
            },
            {
                "box": {
                    "id": "statusgate_toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 690.0, 462.0, 20.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "statusgate",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 690.0, 490.0, 40.0, 22.0 ],
                    "text": "gate"
                }
            },
            {
                "box": {
                    "id": "statusprint",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 690.0, 524.0, 188.0, 22.0 ],
                    "text": "print automation_score_status"
                }
            },
            {
                "box": {
                    "fontsize": 10.0,
                    "id": "viewhint",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 420.0, 212.0, 214.0, 18.0 ],
                    "text": "visual monitor"
                }
            },
            {
                "box": {
                    "id": "viewlanes",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 420.0, 238.0, 78.0, 22.0 ],
                    "text": "view lanes"
                }
            },
            {
                "box": {
                    "id": "viewoverlap",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 506.0, 238.0, 92.0, 22.0 ],
                    "text": "view overlap"
                }
            },
            {
                "box": {
                    "id": "markerson",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 420.0, 364.0, 78.0, 22.0 ],
                    "text": "markers 1"
                }
            },
            {
                "box": {
                    "id": "markersoff",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 506.0, 364.0, 78.0, 22.0 ],
                    "text": "markers 0"
                }
            },
            {
                "box": {
                    "filename": "automation_score_view_v8ui.js",
                    "id": "viewui",
                    "maxclass": "v8ui",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 23.0, 416.0, 606.0, 170.0 ],
                    "textfile": {
                        "filename": "automation_score_view_v8ui.js",
                        "flags": 0,
                        "embed": 0,
                        "autowatch": 1
                    }
                }
            },
            {
                "box": {
                    "id": "gatehint",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 720.0, 148.0, 217.0, 20.0 ],
                    "text": "Open print gates only when debugging."
                }
            }
        ],
        "lines": [
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "cc", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "clockprint", 0 ],
                    "source": [ "clockgate", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "clockgate", 0 ],
                    "source": [ "clockgate_toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "readmsg", 0 ],
                    "source": [ "drop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "generic", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "laneall", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "laneprint", 0 ],
                    "source": [ "lanegate", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "lanegate", 0 ],
                    "source": [ "lanegate_toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "laneone", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "loop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "source": [ "markersoff", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "source": [ "markerson", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "metaprint", 0 ],
                    "source": [ "metagate", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "metagate", 0 ],
                    "source": [ "metagate_toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "tickmsg", 0 ],
                    "source": [ "metro", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "once", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "pal", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "play", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "readmsg", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "reset", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "statusprint", 0 ],
                    "source": [ "statusgate", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "statusgate", 0 ],
                    "source": [ "statusgate_toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "stop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "tickmsg", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "metro", 0 ],
                    "source": [ "toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "clockgate", 1 ],
                    "order": 0,
                    "source": [ "v8", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "lanegate", 1 ],
                    "source": [ "v8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "metagate", 1 ],
                    "order": 0,
                    "source": [ "v8", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "statusgate", 1 ],
                    "source": [ "v8", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "order": 1,
                    "source": [ "v8", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "value", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "source": [ "viewlanes", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "source": [ "viewoverlap", 0 ]
                }
            }
        ],
        "autosave": 0,
        "toolbaradditions": [ "Data Knot", "Vizzie" ],
        "bgcolor": [ 0.12, 0.12, 0.12, 1.0 ]
    }
}
