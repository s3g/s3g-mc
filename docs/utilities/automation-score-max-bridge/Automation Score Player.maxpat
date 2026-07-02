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
        "rect": [
            120,
            120,
            1246,
            625
        ],
        "boxes": [
            {
                "box": {
                    "id": "obj-11",
                    "linecount": 2,
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        576.5,
                        228,
                        35
                    ],
                    "text": "name \"Lane 1\" value 0.583629 enabled 1"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-9",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        "bang"
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        400,
                        557.5,
                        50,
                        22
                    ]
                }
            },
            {
                "box": {
                    "id": "obj-7",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        ""
                    ],
                    "patching_rect": [
                        493,
                        453,
                        68,
                        22
                    ],
                    "text": "route value"
                }
            },
            {
                "box": {
                    "id": "obj-4",
                    "maxclass": "newobj",
                    "numinlets": 9,
                    "numoutlets": 9,
                    "outlettype": [
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        ""
                    ],
                    "patching_rect": [
                        493,
                        420,
                        116,
                        22
                    ],
                    "text": "route 1 2 3 4 5 6 7 8"
                }
            },
            {
                "box": {
                    "id": "obj-1",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        ""
                    ],
                    "patching_rect": [
                        499,
                        364,
                        62,
                        22
                    ],
                    "text": "route lane"
                }
            },
            {
                "box": {
                    "fontsize": 14,
                    "id": "title",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [
                        65.5,
                        14,
                        520,
                        22
                    ],
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
                    "patching_rect": [
                        65.5,
                        36,
                        563,
                        33
                    ],
                    "text": "Drop an Automation Score JSON export here. The v8 script reads breakpoint lanes and outputs interpolated lane values, section changes, and playback metadata."
                }
            },
            {
                "box": {
                    "id": "drop",
                    "maxclass": "dropfile",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        ""
                    ],
                    "patching_rect": [
                        66,
                        96,
                        188,
                        42
                    ]
                }
            },
            {
                "box": {
                    "id": "readmsg",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        66,
                        154,
                        95,
                        22
                    ],
                    "text": "prepend read"
                }
            },
            {
                "box": {
                    "id": "toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [
                        "int"
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        266,
                        96,
                        36,
                        36
                    ]
                }
            },
            {
                "box": {
                    "id": "metro",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        "bang"
                    ],
                    "patching_rect": [
                        266,
                        154,
                        74,
                        22
                    ],
                    "text": "qmetro 33"
                }
            },
            {
                "box": {
                    "id": "tickmsg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        266,
                        194,
                        37,
                        22
                    ],
                    "text": "tick"
                }
            },
            {
                "box": {
                    "id": "play",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        344,
                        194,
                        40,
                        22
                    ],
                    "text": "play"
                }
            },
            {
                "box": {
                    "id": "stop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        394,
                        194,
                        40,
                        22
                    ],
                    "text": "stop"
                }
            },
            {
                "box": {
                    "id": "reset",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        135,
                        180,
                        46,
                        22
                    ],
                    "text": "reset"
                }
            },
            {
                "box": {
                    "id": "loop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        263,
                        196,
                        22
                    ],
                    "text": "playbackmode loop"
                }
            },
            {
                "box": {
                    "id": "pal",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        236,
                        196,
                        22
                    ],
                    "text": "playbackmode palindrome"
                }
            },
            {
                "box": {
                    "id": "once",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        290,
                        115,
                        22
                    ],
                    "text": "playbackmode once"
                }
            },
            {
                "box": {
                    "id": "generic",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        135,
                        202,
                        95,
                        22
                    ],
                    "text": "mode generic"
                }
            },
            {
                "box": {
                    "id": "value",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        135,
                        228,
                        74,
                        22
                    ],
                    "text": "mode value"
                }
            },
            {
                "box": {
                    "id": "cc",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        135,
                        254,
                        74,
                        22
                    ],
                    "text": "mode cc"
                }
            },
            {
                "box": {
                    "id": "laneall",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        168,
                        74,
                        22
                    ],
                    "text": "lane all"
                }
            },
            {
                "box": {
                    "id": "laneone",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        454,
                        195,
                        74,
                        22
                    ],
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
                    "outlettype": [
                        "",
                        "",
                        "",
                        ""
                    ],
                    "patching_rect": [
                        66,
                        275,
                        250,
                        22
                    ],
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
                    "fontsize": 10,
                    "id": "viewhint",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [
                        673,
                        36,
                        221,
                        18
                    ],
                    "text": "automation score monitor"
                }
            },
            {
                "box": {
                    "id": "viewlanes",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        902,
                        36,
                        78,
                        22
                    ],
                    "text": "view lanes"
                }
            },
            {
                "box": {
                    "id": "viewoverlap",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        986,
                        36,
                        92,
                        22
                    ],
                    "text": "view overlap"
                }
            },
            {
                "box": {
                    "id": "markerson",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        902,
                        62,
                        78,
                        22
                    ],
                    "text": "markers 1"
                }
            },
            {
                "box": {
                    "id": "markersoff",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        986,
                        62,
                        78,
                        22
                    ],
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
                    "outlettype": [
                        ""
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        673,
                        72,
                        458,
                        546
                    ],
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
                    "outlettype": [
                        "bang",
                        "bang",
                        ""
                    ],
                    "patching_rect": [
                        344,
                        154,
                        59,
                        22
                    ],
                    "text": "sel 1 0"
                }
            },
            {
                "box": {
                    "id": "debug",
                    "maxclass": "newobj",
                    "numinlets": 4,
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
                        "rect": [
                            813,
                            174,
                            470,
                            300
                        ],
                        "visible": 1,
                        "boxes": [
                            {
                                "box": {
                                    "comment": "",
                                    "id": "in-lane",
                                    "index": 1,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        50,
                                        40,
                                        30,
                                        30
                                    ]
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
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        126,
                                        40,
                                        30,
                                        30
                                    ]
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
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        202,
                                        40,
                                        30,
                                        30
                                    ]
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
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        281,
                                        40,
                                        30,
                                        30
                                    ]
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-lane",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        "int"
                                    ],
                                    "parameter_enable": 0,
                                    "patching_rect": [
                                        50,
                                        96,
                                        24,
                                        24
                                    ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-lane",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        50,
                                        130,
                                        52,
                                        22
                                    ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-lane",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [
                                        50,
                                        230,
                                        174,
                                        22
                                    ],
                                    "text": "print automation_score_lane"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-clock",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        "int"
                                    ],
                                    "parameter_enable": 0,
                                    "patching_rect": [
                                        126,
                                        96,
                                        24,
                                        24
                                    ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-clock",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        126,
                                        130,
                                        52,
                                        22
                                    ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-clock",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [
                                        126,
                                        198,
                                        184,
                                        22
                                    ],
                                    "text": "print automation_score_clock"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-meta",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        "int"
                                    ],
                                    "parameter_enable": 0,
                                    "patching_rect": [
                                        202,
                                        96,
                                        24,
                                        24
                                    ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        202,
                                        130,
                                        52,
                                        22
                                    ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [
                                        202,
                                        164,
                                        180,
                                        22
                                    ],
                                    "text": "print automation_score_meta"
                                }
                            },
                            {
                                "box": {
                                    "id": "tog-status",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        "int"
                                    ],
                                    "parameter_enable": 0,
                                    "patching_rect": [
                                        281,
                                        96,
                                        24,
                                        24
                                    ]
                                }
                            },
                            {
                                "box": {
                                    "id": "gate-status",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [
                                        ""
                                    ],
                                    "patching_rect": [
                                        281,
                                        130,
                                        52,
                                        22
                                    ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "print-status",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [
                                        281,
                                        230,
                                        188,
                                        22
                                    ],
                                    "text": "print automation_score_status"
                                }
                            }
                        ],
                        "lines": [
                            {
                                "patchline": {
                                    "destination": [
                                        "print-clock",
                                        0
                                    ],
                                    "source": [
                                        "gate-clock",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "print-lane",
                                        0
                                    ],
                                    "source": [
                                        "gate-lane",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "print-meta",
                                        0
                                    ],
                                    "source": [
                                        "gate-meta",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "print-status",
                                        0
                                    ],
                                    "source": [
                                        "gate-status",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-clock",
                                        1
                                    ],
                                    "source": [
                                        "in-clock",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-lane",
                                        1
                                    ],
                                    "source": [
                                        "in-lane",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-meta",
                                        1
                                    ],
                                    "source": [
                                        "in-meta",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-status",
                                        1
                                    ],
                                    "source": [
                                        "in-status",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-clock",
                                        0
                                    ],
                                    "source": [
                                        "tog-clock",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-lane",
                                        0
                                    ],
                                    "source": [
                                        "tog-lane",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-meta",
                                        0
                                    ],
                                    "source": [
                                        "tog-meta",
                                        0
                                    ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [
                                        "gate-status",
                                        0
                                    ],
                                    "source": [
                                        "tog-status",
                                        0
                                    ]
                                }
                            }
                        ],
                        "toolbaradditions": [
                            "Data Knot",
                            "Vizzie"
                        ]
                    },
                    "patching_rect": [
                        66,
                        310,
                        250,
                        22
                    ],
                    "text": "p console_debugging"
                }
            },
            {
                "box": {
                    "id": "totalroute",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        ""
                    ],
                    "patching_rect": [
                        220,
                        387,
                        110,
                        22
                    ],
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
                    "outlettype": [
                        "",
                        "bang"
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        220,
                        421,
                        92,
                        22
                    ]
                }
            },
            {
                "box": {
                    "id": "total_label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [
                        310,
                        422,
                        104,
                        20
                    ],
                    "text": "total seconds"
                }
            },
            {
                "box": {
                    "id": "scrub_label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [
                        481.5,
                        484,
                        104,
                        20
                    ],
                    "text": "scrub"
                }
            },
            {
                "box": {
                    "id": "scrub_size",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        220,
                        457,
                        59,
                        22
                    ],
                    "text": "size $1"
                }
            },
            {
                "box": {
                    "id": "scrub_slider",
                    "maxclass": "slider",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        220,
                        488,
                        254,
                        12
                    ],
                    "size": 16
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "position_number",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [
                        "",
                        "bang"
                    ],
                    "parameter_enable": 0,
                    "patching_rect": [
                        220,
                        551,
                        70,
                        22
                    ]
                }
            },
            {
                "box": {
                    "id": "seconds_msg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        220,
                        583,
                        82,
                        22
                    ],
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
                    "patching_rect": [
                        17,
                        657,
                        630,
                        33
                    ],
                    "text": "Outlet 1: lane messages. OSC mode: /automation /lane n /value normalized-value. Generic mode: lane index name lane-name value normalized-value enabled 1. Value mode: value index normalized-value. CC mode: cc index 0-to-127."
                }
            },
            {
                "box": {
                    "id": "osc",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [
                        ""
                    ],
                    "patching_rect": [
                        218,
                        202,
                        74,
                        22
                    ],
                    "text": "mode osc"
                }
            }
        ],
        "lines": [
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "cc",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "readmsg",
                        0
                    ],
                    "source": [
                        "drop",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "generic",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "laneall",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "laneone",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "loop",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "viewui",
                        0
                    ],
                    "source": [
                        "markersoff",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "viewui",
                        0
                    ],
                    "source": [
                        "markerson",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "tickmsg",
                        0
                    ],
                    "source": [
                        "metro",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "obj-4",
                        0
                    ],
                    "source": [
                        "obj-1",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "obj-11",
                        1
                    ],
                    "order": 0,
                    "source": [
                        "obj-4",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "obj-7",
                        0
                    ],
                    "order": 1,
                    "source": [
                        "obj-4",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "obj-9",
                        0
                    ],
                    "source": [
                        "obj-7",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "once",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "pal",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "play",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "seconds_msg",
                        0
                    ],
                    "source": [
                        "position_number",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "readmsg",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "reset",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "scrub_slider",
                        0
                    ],
                    "source": [
                        "scrub_size",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "position_number",
                        0
                    ],
                    "source": [
                        "scrub_slider",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "seconds_msg",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "play",
                        0
                    ],
                    "source": [
                        "sel",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "stop",
                        0
                    ],
                    "source": [
                        "sel",
                        1
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "stop",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "tickmsg",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "metro",
                        0
                    ],
                    "order": 1,
                    "source": [
                        "toggle",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "sel",
                        0
                    ],
                    "order": 0,
                    "source": [
                        "toggle",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "scrub_size",
                        0
                    ],
                    "order": 0,
                    "source": [
                        "totalroute",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "total_seconds",
                        0
                    ],
                    "order": 1,
                    "source": [
                        "totalroute",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "debug",
                        3
                    ],
                    "source": [
                        "v8",
                        3
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "debug",
                        2
                    ],
                    "order": 1,
                    "source": [
                        "v8",
                        2
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "debug",
                        1
                    ],
                    "source": [
                        "v8",
                        1
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "debug",
                        0
                    ],
                    "order": 1,
                    "source": [
                        "v8",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "obj-1",
                        0
                    ],
                    "order": 0,
                    "source": [
                        "v8",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "totalroute",
                        0
                    ],
                    "order": 2,
                    "source": [
                        "v8",
                        2
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "viewui",
                        0
                    ],
                    "order": 0,
                    "source": [
                        "v8",
                        2
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "v8",
                        0
                    ],
                    "source": [
                        "value",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "viewui",
                        0
                    ],
                    "source": [
                        "viewlanes",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "destination": [
                        "viewui",
                        0
                    ],
                    "source": [
                        "viewoverlap",
                        0
                    ]
                }
            },
            {
                "patchline": {
                    "source": [
                        "osc",
                        0
                    ],
                    "destination": [
                        "v8",
                        0
                    ]
                }
            }
        ],
        "autosave": 0,
        "toolbaradditions": [
            "Data Knot",
            "Vizzie"
        ]
    }
}
