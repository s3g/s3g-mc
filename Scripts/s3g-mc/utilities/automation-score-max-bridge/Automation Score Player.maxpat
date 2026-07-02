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
        "rect": [ 77.0, 115.0, 1360.0, 671.0 ],
        "boxes": [
            {
                "box": {
                    "format": 6,
                    "id": "obj-49",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 535.5, 612.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-47",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 477.57142857142867, 616.0, 50.0, 22.0 ],
                    "text": "B"
                }
            },
            {
                "box": {
                    "id": "obj-46",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 331.0, 616.0, 50.0, 22.0 ],
                    "text": "A"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-44",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 382.07142857142867, 613.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-42",
                    "linecount": 2,
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 642.0, 566.0, 50.0, 35.0 ],
                    "text": "A 0 bang"
                }
            },
            {
                "box": {
                    "id": "obj-34",
                    "maxclass": "button",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 592.0, 611.0, 24.0, 24.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-35",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 3,
                    "outlettype": [ "", "float", "" ],
                    "patching_rect": [ 477.57142857142867, 577.0, 73.0, 22.0 ],
                    "text": "unpack s f b"
                }
            },
            {
                "box": {
                    "id": "obj-33",
                    "maxclass": "button",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 443.57142857142867, 612.0, 24.0, 24.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-31",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 3,
                    "outlettype": [ "", "float", "" ],
                    "patching_rect": [ 370.57142857142867, 577.0, 73.0, 22.0 ],
                    "text": "unpack s f b"
                }
            },
            {
                "box": {
                    "id": "obj-25",
                    "maxclass": "newobj",
                    "numinlets": 3,
                    "numoutlets": 3,
                    "outlettype": [ "", "", "" ],
                    "patching_rect": [ 370.57142857142867, 545.0, 56.0, 22.0 ],
                    "text": "route 1 2"
                }
            },
            {
                "box": {
                    "id": "obj-1",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 371.0, 513.0, 143.0, 22.0 ],
                    "text": "route /automation/marker"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-74",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 739.0000000000002, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-73",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 8,
                    "outlettype": [ "", "", "", "", "", "", "", "" ],
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
                        "rect": [ 59.0, 106.0, 686.0, 362.0 ],
                        "boxes": [
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-3",
                                    "index": 8,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 561.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-6",
                                    "maxclass": "newobj",
                                    "numinlets": 9,
                                    "numoutlets": 9,
                                    "outlettype": [ "", "", "", "", "", "", "", "", "" ],
                                    "patching_rect": [ 50.0, 158.0, 603.0, 22.0 ],
                                    "text": "route 1 2 3 4 5 6 7 8"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-1",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 2,
                                    "outlettype": [ "", "" ],
                                    "patching_rect": [ 50.0, 100.0, 128.0, 22.0 ],
                                    "text": "route /automation/lane"
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-65",
                                    "index": 1,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 50.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-66",
                                    "index": 1,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 50.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-67",
                                    "index": 2,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 123.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-68",
                                    "index": 3,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 196.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-69",
                                    "index": 4,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 269.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-70",
                                    "index": 5,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 342.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-71",
                                    "index": 6,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 415.0, 269.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-72",
                                    "index": 7,
                                    "maxclass": "outlet",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 488.0, 269.0, 30.0, 30.0 ]
                                }
                            }
                        ],
                        "lines": [
                            {
                                "patchline": {
                                    "destination": [ "obj-6", 0 ],
                                    "source": [ "obj-1", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-3", 0 ],
                                    "source": [ "obj-6", 7 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-66", 0 ],
                                    "source": [ "obj-6", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-67", 0 ],
                                    "source": [ "obj-6", 1 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-68", 0 ],
                                    "source": [ "obj-6", 2 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-69", 0 ],
                                    "source": [ "obj-6", 3 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-70", 0 ],
                                    "source": [ "obj-6", 4 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-71", 0 ],
                                    "source": [ "obj-6", 5 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-72", 0 ],
                                    "source": [ "obj-6", 6 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-1", 0 ],
                                    "source": [ "obj-65", 0 ]
                                }
                            }
                        ],
                        "toolbaradditions": [ "Data Knot", "Vizzie" ]
                    },
                    "patching_rect": [ 373.0, 392.0, 385.0000000000002, 22.0 ],
                    "text": "p osc-style-routing"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-63",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 686.7142857142859, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-61",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 634.4285714285716, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-19",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 582.1428571428573, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-17",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 529.8571428571429, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-15",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 477.57142857142867, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-13",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 425.28571428571433, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-11",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 373.0, 452.0, 50.0, 22.0 ]
                }
            },
            {
                "box": {
                    "fontsize": 14.0,
                    "id": "title",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 65.5, 14.0, 520.0, 22.0 ],
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
                    "patching_rect": [ 65.5, 36.0, 563.0, 33.0 ],
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
                    "patching_rect": [ 66.0, 96.0, 188.0, 42.0 ]
                }
            },
            {
                "box": {
                    "id": "readmsg",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 66.0, 154.0, 95.0, 22.0 ],
                    "text": "prepend read"
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
                    "patching_rect": [ 266.0, 96.0, 36.0, 36.0 ]
                }
            },
            {
                "box": {
                    "id": "metro",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "bang" ],
                    "patching_rect": [ 266.0, 154.0, 74.0, 22.0 ],
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
                    "patching_rect": [ 266.0, 194.0, 37.0, 22.0 ],
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
                    "patching_rect": [ 344.0, 194.0, 40.0, 22.0 ],
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
                    "patching_rect": [ 394.0, 194.0, 40.0, 22.0 ],
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
                    "patching_rect": [ 306.0, 96.0, 46.0, 22.0 ],
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
                    "patching_rect": [ 470.5, 275.0, 196.0, 22.0 ],
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
                    "patching_rect": [ 470.5, 248.0, 196.0, 22.0 ],
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
                    "patching_rect": [ 470.5, 302.0, 115.0, 22.0 ],
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
                    "patching_rect": [ 158.5, 182.0, 95.0, 22.0 ],
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
                    "patching_rect": [ 82.0, 206.0, 74.0, 22.0 ],
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
                    "patching_rect": [ 158.5, 206.0, 74.0, 22.0 ],
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
                    "patching_rect": [ 470.5, 194.0, 74.0, 22.0 ],
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
                    "patching_rect": [ 470.5, 221.0, 74.0, 22.0 ],
                    "text": "lane 1"
                }
            },
            {
                "box": {
                    "filename": "automation_score_player_v8.js",
                    "id": "v8",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 5,
                    "outlettype": [ "", "", "", "", "" ],
                    "patching_rect": [ 66.0, 275.0, 250.0, 22.0 ],
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
                    "fontsize": 10.0,
                    "id": "viewhint",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 855.0, 41.0, 221.0, 18.0 ],
                    "text": "automation score monitor"
                }
            },
            {
                "box": {
                    "id": "viewlanes",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 666.0, 21.0, 78.0, 22.0 ],
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
                    "patching_rect": [ 750.0, 21.0, 92.0, 22.0 ],
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
                    "patching_rect": [ 666.0, 47.0, 78.0, 22.0 ],
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
                    "patching_rect": [ 750.0, 47.0, 78.0, 22.0 ],
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
                    "patching_rect": [ 855.0, 77.0, 458.0, 550.0 ],
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
                    "id": "sel",
                    "maxclass": "newobj",
                    "numinlets": 3,
                    "numoutlets": 3,
                    "outlettype": [ "bang", "bang", "" ],
                    "patching_rect": [ 344.0, 154.0, 59.0, 22.0 ],
                    "text": "sel 1 0"
                }
            },
            {
                "box": {
                    "id": "debug",
                    "maxclass": "newobj",
                    "numinlets": 5,
                    "numoutlets": 0,
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
                        "rect": [ 813.0, 174.0, 791.0, 300.0 ],
                        "boxes": [
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-4",
                                    "index": 5,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 409.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-1",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 376.0, 96.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-2",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 376.0, 130.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-3",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 376.0, 164.0, 67.0, 22.0 ],
                                    "text": "print status"
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "in-lane",
                                    "index": 1,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 83.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "in-clock",
                                    "index": 2,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 159.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "in-meta",
                                    "index": 3,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 235.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "in-status",
                                    "index": 4,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 328.0, 40.0, 30.0, 30.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-lane",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 50.0, 96.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-lane",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 50.0, 130.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-lane",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 50.0, 164.0, 64.0, 22.0 ],
                                    "text": "print lanes"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-clock",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 126.0, 96.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-clock",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 126.0, 130.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-clock",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 126.0, 164.0, 63.0, 22.0 ],
                                    "text": "print clock"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-meta",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 202.0, 96.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 202.0, 130.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 202.0, 164.0, 85.0, 22.0 ],
                                    "text": "print metadata"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-status",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 295.0, 96.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-status",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 295.0, 130.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-status",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 295.0, 164.0, 75.0, 22.0 ],
                                    "text": "print makers"
                                }
                            }
                        ],
                        "lines": [
                            {
                                "patchline": {
                                    "destination": [ "print-clock", 0 ],
                                    "source": [ "gate-clock", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "print-lane", 0 ],
                                    "source": [ "gate-lane", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "print-meta", 0 ],
                                    "source": [ "gate-meta", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "print-status", 0 ],
                                    "source": [ "gate-status", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-clock", 1 ],
                                    "source": [ "in-clock", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-lane", 1 ],
                                    "source": [ "in-lane", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-meta", 1 ],
                                    "source": [ "in-meta", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-status", 1 ],
                                    "source": [ "in-status", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-2", 0 ],
                                    "source": [ "obj-1", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-3", 0 ],
                                    "source": [ "obj-2", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-2", 1 ],
                                    "source": [ "obj-4", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-clock", 0 ],
                                    "source": [ "tog-clock", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-lane", 0 ],
                                    "source": [ "tog-lane", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-meta", 0 ],
                                    "source": [ "tog-meta", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "gate-status", 0 ],
                                    "source": [ "tog-status", 0 ]
                                }
                            }
                        ],
                        "toolbaradditions": [ "Data Knot", "Vizzie" ]
                    },
                    "patching_rect": [ 66.0, 310.0, 250.0, 22.0 ],
                    "text": "p console_debugging"
                }
            },
            {
                "box": {
                    "id": "totalroute",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 64.0, 387.0, 110.0, 22.0 ],
                    "text": "route duration"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "total_seconds",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 64.0, 421.0, 92.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "total_label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 154.0, 422.0, 104.0, 20.0 ],
                    "text": "total seconds"
                }
            },
            {
                "box": {
                    "id": "scrub_label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 280.0, 502.0, 38.0, 20.0 ],
                    "text": "scrub"
                }
            },
            {
                "box": {
                    "id": "scrub_size",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 64.0, 457.0, 59.0, 22.0 ],
                    "text": "size $1"
                }
            },
            {
                "box": {
                    "id": "scrub_slider",
                    "maxclass": "slider",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 64.0, 488.0, 254.0, 12.0 ],
                    "size": 16.0
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "position_number",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 64.0, 551.0, 70.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "seconds_msg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 64.0, 583.0, 82.0, 22.0 ],
                    "text": "seconds $1"
                }
            },
            {
                "box": {
                    "id": "route_note",
                    "linecount": 2,
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 17.0, 657.0, 640.0, 33.0 ],
                    "text": "Outlet 1: lane messages. OSC mode: /automation /lane n /value normalized-value. Generic mode: lane index name lane-name value normalized-value enabled 1. Value mode: value index normalized-value. CC mode: cc index 0-to-127."
                }
            },
            {
                "box": {
                    "id": "osc",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 82.0, 182.0, 74.0, 22.0 ],
                    "text": "mode osc"
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
                    "destination": [ "tickmsg", 0 ],
                    "source": [ "metro", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-25", 0 ],
                    "source": [ "obj-1", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-31", 0 ],
                    "order": 1,
                    "source": [ "obj-25", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-35", 0 ],
                    "source": [ "obj-25", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-42", 1 ],
                    "order": 0,
                    "source": [ "obj-25", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-33", 0 ],
                    "source": [ "obj-31", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-44", 0 ],
                    "source": [ "obj-31", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-46", 1 ],
                    "source": [ "obj-31", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-34", 0 ],
                    "source": [ "obj-35", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-47", 1 ],
                    "source": [ "obj-35", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-49", 0 ],
                    "source": [ "obj-35", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-11", 0 ],
                    "source": [ "obj-73", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-13", 0 ],
                    "source": [ "obj-73", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-15", 0 ],
                    "source": [ "obj-73", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-17", 0 ],
                    "source": [ "obj-73", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-19", 0 ],
                    "source": [ "obj-73", 4 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-61", 0 ],
                    "source": [ "obj-73", 5 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-63", 0 ],
                    "source": [ "obj-73", 6 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-74", 0 ],
                    "source": [ "obj-73", 7 ]
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
                    "source": [ "osc", 0 ]
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
                    "destination": [ "seconds_msg", 0 ],
                    "source": [ "position_number", 0 ]
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
                    "destination": [ "scrub_slider", 0 ],
                    "source": [ "scrub_size", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "position_number", 0 ],
                    "source": [ "scrub_slider", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "v8", 0 ],
                    "source": [ "seconds_msg", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "play", 0 ],
                    "source": [ "sel", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "stop", 0 ],
                    "source": [ "sel", 1 ]
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
                    "order": 1,
                    "source": [ "toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "sel", 0 ],
                    "order": 0,
                    "source": [ "toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "scrub_size", 0 ],
                    "order": 0,
                    "source": [ "totalroute", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "total_seconds", 0 ],
                    "order": 1,
                    "source": [ "totalroute", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "debug", 3 ],
                    "order": 1,
                    "source": [ "v8", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "debug", 2 ],
                    "order": 1,
                    "source": [ "v8", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "debug", 1 ],
                    "source": [ "v8", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "debug", 0 ],
                    "order": 1,
                    "source": [ "v8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-1", 0 ],
                    "order": 0,
                    "source": [ "v8", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-73", 0 ],
                    "order": 0,
                    "source": [ "v8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "totalroute", 0 ],
                    "order": 2,
                    "source": [ "v8", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "viewui", 0 ],
                    "order": 0,
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
        "toolbaradditions": [ "Data Knot", "Vizzie" ]
    }
}