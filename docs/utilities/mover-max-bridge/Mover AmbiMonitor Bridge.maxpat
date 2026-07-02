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
        "rect": [ 272.0, 96.0, 1201.0, 650.0 ],
        "description": "Playback bridge for s3g-mc Mover JSON automation. Outputs interpolated AED / distance / gain messages for AmbiMonitor mapping.",
        "tags": "s3g-mc, mover, ambisonics, ambimonitor",
        "boxes": [
            {
                "box": {
                    "id": "obj-9",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 481.5, 484.0, 104.0, 20.0 ],
                    "text": "scrub"
                }
            },
            {
                "box": {
                    "id": "obj-7",
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
                        "rect": [ 59.0, 106.0, 488.0, 328.0 ],
                        "boxes": [
                            {
                                "box": {
                                    "id": "obj-print-source",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 50.0, 242.0, 170.0, 22.0 ],
                                    "text": "print mover_source"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-position",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 126.0, 215.0, 153.0, 22.0 ],
                                    "text": "print mover_position"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 202.0, 188.0, 130.0, 22.0 ],
                                    "text": "print mover_meta"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-status",
                                    "maxclass": "newobj",
                                    "numinlets": 1,
                                    "numoutlets": 0,
                                    "patching_rect": [ 281.0, 161.0, 140.0, 22.0 ],
                                    "text": "print mover_status"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-toggle-source",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 50.0, 186.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-gate-source",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 50.0, 215.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-toggle-position",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 126.0, 155.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-gate-position",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 126.0, 186.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-toggle-meta",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 202.0, 130.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-gate-meta",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 202.0, 160.0, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-toggle-status",
                                    "maxclass": "toggle",
                                    "numinlets": 1,
                                    "numoutlets": 1,
                                    "outlettype": [ "int" ],
                                    "parameter_enable": 0,
                                    "patching_rect": [ 281.0, 100.0, 24.0, 24.0 ]
                                }
                            },
                            {
                                "box": {
                                    "id": "obj-print-gate-status",
                                    "maxclass": "newobj",
                                    "numinlets": 2,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 281.0, 131.5, 52.0, 22.0 ],
                                    "text": "gate"
                                }
                            },
                            {
                                "box": {
                                    "comment": "",
                                    "id": "obj-3",
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
                                    "id": "obj-4",
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
                                    "id": "obj-5",
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
                                    "id": "obj-6",
                                    "index": 4,
                                    "maxclass": "inlet",
                                    "numinlets": 0,
                                    "numoutlets": 1,
                                    "outlettype": [ "" ],
                                    "patching_rect": [ 314.0, 40.0, 30.0, 30.0 ]
                                }
                            }
                        ],
                        "lines": [
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-source", 1 ],
                                    "source": [ "obj-3", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-position", 1 ],
                                    "source": [ "obj-4", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-meta", 1 ],
                                    "source": [ "obj-5", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-status", 1 ],
                                    "source": [ "obj-6", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-meta", 0 ],
                                    "source": [ "obj-print-gate-meta", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-position", 0 ],
                                    "source": [ "obj-print-gate-position", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-source", 0 ],
                                    "source": [ "obj-print-gate-source", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-status", 0 ],
                                    "source": [ "obj-print-gate-status", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-meta", 0 ],
                                    "source": [ "obj-print-toggle-meta", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-position", 0 ],
                                    "source": [ "obj-print-toggle-position", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-source", 0 ],
                                    "source": [ "obj-print-toggle-source", 0 ]
                                }
                            },
                            {
                                "patchline": {
                                    "destination": [ "obj-print-gate-status", 0 ],
                                    "source": [ "obj-print-toggle-status", 0 ]
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
                    "id": "obj-1",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 403.0, 291.0, 87.0, 22.0 ],
                    "text": "s mover_script"
                }
            },
            {
                "box": {
                    "id": "obj-13",
                    "maxclass": "newobj",
                    "numinlets": 0,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 673.0, 36.0, 211.0, 22.0 ],
                    "text": "r mover_ambimonitor_messages"
                }
            },
            {
                "box": {
                    "id": "obj-10",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 220.0, 457.0, 59.0, 22.0 ],
                    "text": "size $1"
                }
            },
            {
                "box": {
                    "floatoutput": 1,
                    "id": "obj-8",
                    "maxclass": "slider",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 220.0, 488.0, 254.0, 12.0 ],
                    "size": 16.0
                }
            },
            {
                "box": {
                    "bgcolor": [ 0.0588, 0.0588, 0.0588, 1.0 ],
                    "grid_display": 1,
                    "grid_unit_ae": 4,
                    "id": "obj-2",
                    "maxclass": "ambimonitor",
                    "mode": 2,
                    "numbers": 1,
                    "numinlets": 1,
                    "numoutlets": 3,
                    "outlettype": [ "", "", "" ],
                    "patching_rect": [ 673.0, 72.0, 273.0, 546.0 ],
                    "point_color": [ 0.4314, 0.9059, 0.949, 1.0 ],
                    "point_size": 7.99,
                    "zoom_scale": 0.7
                }
            },
            {
                "box": {
                    "id": "obj-title",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 65.5, 14.0, 520.0, 20.0 ],
                    "text": "Mover AmbiMonitor Bridge"
                }
            },
            {
                "box": {
                    "id": "obj-help",
                    "linecount": 3,
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 65.5, 36.0, 563.0, 47.0 ],
                    "text": "Drop a Mover JSON export here. The v8 script reads exported automation points and interpolates them during playback. Generic mode includes gain. ICST mode outputs: aed index azimuth elevation distance."
                }
            },
            {
                "box": {
                    "id": "obj-drop",
                    "maxclass": "dropfile",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 66.0, 96.0, 188.0, 42.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-prepend-read",
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
                    "id": "obj-toggle",
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
                    "id": "obj-sel",
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
                    "id": "obj-play",
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
                    "id": "obj-stop",
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
                    "id": "obj-qmetro",
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
                    "id": "obj-tick",
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
                    "id": "obj-reset",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 135.0, 180.0, 46.0, 22.0 ],
                    "text": "reset"
                }
            },
            {
                "box": {
                    "id": "obj-mode-generic",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 135.0, 202.0, 95.0, 22.0 ],
                    "text": "mode generic"
                }
            },
            {
                "box": {
                    "id": "obj-mode-icst",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 135.0, 228.0, 74.0, 22.0 ],
                    "text": "mode icst"
                }
            },
            {
                "box": {
                    "id": "obj-group-all",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 454.0, 168.0, 74.0, 22.0 ],
                    "text": "group all"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-position",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 220.0, 511.0, 70.0, 22.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-position-msg",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 220.0, 551.0, 82.0, 22.0 ],
                    "text": "seconds $1"
                }
            },
            {
                "box": {
                    "filename": "mover_ambimonitor_bridge_v8.js",
                    "id": "obj-v8",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 4,
                    "outlettype": [ "", "", "", "" ],
                    "patching_rect": [ 66.0, 275.0, 250.0, 22.0 ],
                    "saved_object_attributes": {
                        "parameter_enable": 0
                    },
                    "text": "v8 mover_ambimonitor_bridge_v8.js",
                    "textfile": {
                        "filename": "mover_ambimonitor_bridge_v8.js",
                        "flags": 0,
                        "embed": 0,
                        "autowatch": 1
                    }
                }
            },
            {
                "box": {
                    "id": "obj-route-note",
                    "linecount": 2,
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 17.0, 657.0, 608.0, 33.0 ],
                    "text": "Outlet 1: source messages. Generic mode: source index group n source n azimuth deg elevation deg distance n gain n. ICST mode: aed index azimuth elevation distance."
                }
            },
            {
                "box": {
                    "id": "obj-send",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 66.0, 343.0, 211.0, 22.0 ],
                    "text": "s mover_ambimonitor_messages"
                }
            },
            {
                "box": {
                    "id": "obj-playback-one",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 454.0, 249.0, 82.0, 22.0 ],
                    "text": "playbackmode once"
                }
            },
            {
                "box": {
                    "id": "obj-playback-loop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 454.0, 222.0, 196.0, 22.0 ],
                    "text": "playbackmode loop"
                }
            },
            {
                "box": {
                    "id": "obj-playback-pal",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 454.0, 195.0, 196.0, 22.0 ],
                    "text": "playbackmode palindrome"
                }
            },
            {
                "box": {
                    "id": "obj-total-route",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 220.0, 387.0, 110.0, 22.0 ],
                    "text": "route duration"
                }
            },
            {
                "box": {
                    "id": "obj-total-label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 310.0, 422.0, 104.0, 20.0 ],
                    "text": "total seconds"
                }
            },
            {
                "box": {
                    "format": 6,
                    "id": "obj-total-seconds",
                    "maxclass": "flonum",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "bang" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 220.0, 421.0, 92.0, 22.0 ]
                }
            }
        ],
        "lines": [
            {
                "patchline": {
                    "destination": [ "obj-8", 0 ],
                    "source": [ "obj-10", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-2", 0 ],
                    "source": [ "obj-13", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-position", 0 ],
                    "source": [ "obj-8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-prepend-read", 0 ],
                    "source": [ "obj-drop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-1", 0 ],
                    "source": [ "obj-group-all", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-mode-generic", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-mode-icst", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-play", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-playback-loop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-playback-one", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-playback-pal", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-position-msg", 0 ],
                    "source": [ "obj-position", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "midpoints": [ 229.5, 594.85546875, 44.77734375, 594.85546875, 44.77734375, 260.26171875, 75.5, 260.26171875 ],
                    "source": [ "obj-position-msg", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-prepend-read", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-tick", 0 ],
                    "source": [ "obj-qmetro", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-reset", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-play", 0 ],
                    "source": [ "obj-sel", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-stop", 0 ],
                    "source": [ "obj-sel", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-stop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-v8", 0 ],
                    "source": [ "obj-tick", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-qmetro", 0 ],
                    "order": 1,
                    "source": [ "obj-toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-sel", 0 ],
                    "order": 0,
                    "source": [ "obj-toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-total-seconds", 0 ],
                    "source": [ "obj-total-route", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-10", 0 ],
                    "source": [ "obj-total-seconds", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-7", 3 ],
                    "source": [ "obj-v8", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-7", 2 ],
                    "order": 0,
                    "source": [ "obj-v8", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-7", 1 ],
                    "source": [ "obj-v8", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-7", 0 ],
                    "order": 0,
                    "source": [ "obj-v8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-send", 0 ],
                    "order": 1,
                    "source": [ "obj-v8", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-total-route", 0 ],
                    "order": 1,
                    "source": [ "obj-v8", 2 ]
                }
            }
        ],
        "autosave": 0,
        "toolbaradditions": [ "Data Knot", "Vizzie" ]
    }
}
