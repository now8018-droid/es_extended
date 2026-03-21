$(function () {

    let CaseList = {}

    let Notify = true

    let casefilter = {
        bodybag:true,
        normal:true,
        waiting:true,
        going:true,
        safe:true
    }

    let search = ""

    let blacklistwindows = false

    var AlertSound = new Audio('sounds/damage.mp3');
    AlertSound.volume = 0.5;

    var ClickSound = new Audio('sounds/tiksound.ogg');
    ClickSound.volume = 0.2;

    window.addEventListener('message', function(event) {
        var item = event.data;
        if (item.type == "Toggle") {
            ToggleUI(item.status)
        }
        if (item.type == "RefreshCase") {
            CaseList = item.data
            RefreshCaseList()
        }
        if (item.type == "UpdateCaseTime") {
            if (item.data) {
                item.data.forEach((caseTimeData) => {
                    const caseId = String(caseTimeData.caseid);
                    const caseData = findCaseByCaseId(caseId);
                    if (caseData) {
                        caseData.casetime = caseTimeData.casetime;
                        caseData.remaintext = caseTimeData.remaintext;
                    }

                    const timeEl = $(`.casetime[data-caseid=\"${caseId}\"]`);
                    if (timeEl.length) {
                        timeEl.html(caseTimeData.casetime || '-');
                    }

                    const detailEl = $(`.case-owner-detail[data-caseid=\"${caseId}\"]`);
                    if (detailEl.length && caseData) {
                        const pressCount = Number(caseData.pressedCount || 1);
                        const pressText = pressCount > 1 ? ` | X${pressCount}` : '';
                        detailEl.html(`${caseData.caseid || "-"} | [${caseTimeData.remaintext || "00:00"}]${pressText}`);
                    }
                });
            }
        }
        if (item.type == "AlertUI") {
            if (Notify) {
                AlertSound.play()
                $("#alerttext").html(item.text);
                $(".Alert").fadeIn(300);
                setTimeout(function() {
                    $(".Alert").fadeOut(300);
                }, 5000);
            }
        }
        if (item.type == "RefreshBlackList") {
            if (item.data) {
                $(".listblacklistnunber").empty();
                for (key in item.data) {
                    $(".listblacklistnunber").append("<div>"+(key)+"</div>");
                }
            }
        }
    })

    function ToggleUI(status) {
        if (status) {
            $(".container").show();
        } else {
            $(".container").hide();
        }
    }


    function findCaseByCaseId(caseId) {
        for (const key in CaseList) {
            const caseData = CaseList[key];
            if (String(caseData.caseid) === String(caseId)) {
                return caseData;
            }
        }

        return null;
    }

    function RefreshCaseList() {
        let CaseCount = {
            [1]:0,
            [2]:0,
            [3]:0,
        }
        $(".caselist").empty();

        const sortedCases = Object.values(CaseList || {}).sort((a, b) => {
            const orderA = Number(a.caseorder || a.caseid || 0);
            const orderB = Number(b.caseorder || b.caseid || 0);
            return orderB - orderA;
        });

        for (const v of sortedCases) {

            let showidcase = false

            if (casefilter) {
                if (casefilter.bodybag) {
                    if (v.type == "bodybag") {
                        showidcase = true
                    }
                }

                if (v.type != "bodybag") {
                    if (casefilter.waiting) {
                        if (v.status == 1) {
                            showidcase = true
                        }
                    }
                    if (casefilter.going) {
                        if (v.status == 2) {
                            showidcase = true
                        }
                    }
                    if (casefilter.safe) {
                        if (v.status == 3) {
                            showidcase = true
                        }
                    }
                    if (!casefilter.normal) {
                        showidcase = false
                    }
                }
            }
            if (showidcase) {
                let text = v.text || ""
                if (v.status == 1) {
                    const pressCount = Number(v.pressedCount || 1)
                    const pressText = pressCount > 1 ? ` X${pressCount}` : ''
                    text = `<span style="color:#ff686880;">${v.text || "ต้องการความช่วยเหลือ"}${pressText}</span>`
                }
                if (v.status == 2) {
                    text = '<span style="color:#ffbc00b8;">'+(v.text || "กำลังไป")+'</span>'
                }
                if (v.status == 3) {
                    text = '<span style="color:#00b2ff;">ปลอดภัยแล้ว</span>'
                }

                let statusIconClass = 'is-waiting'
                if (v.status == 2) {
                    statusIconClass = 'is-going'
                } else if (v.status == 3) {
                    statusIconClass = 'is-safe'
                }

                let caseOwner = v.name || "ไม่ทราบชื่อ"
                let caseRemain = v.remaintext || "00:00"
                let pressCount = Number(v.pressedCount || 1)
                let pressText = pressCount > 1 ? ` | X${pressCount}` : ''
                let caseOwnerDetail = `${v.caseid || "-"} | [${caseRemain}]${pressText}`

                $(".caselist").append(`
                    <div class="casevalue status-${v.status}" data-caseid="${v.caseid}">
                        <div class="caseid">${v.caseorder || v.caseid}</div>
                        <div class="casetime" data-caseid="${v.caseid}">${v.casetime || "-"}</div>
                        <div class="phonenumber"><div class="case-owner">${caseOwner}</div><div class="case-owner-detail" data-caseid="${v.caseid}">${caseOwnerDetail}</div></div>
                        <div class="status"><span class="status-icon ${statusIconClass}"></span>${text}</div>
                        <div><img src="img/getbtn.png" class="getbtn casebtn" data-caseid="${v.caseid}"></div>
                        <div><img src="img/gpsbtn.png" class="gpsbtn casebtn" data-caseid="${v.caseid}"></div>
                        <div><img src="img/deletebtn.png" class="deletebtn casebtn" data-caseid="${v.caseid}" data-status="${v.status}" style="${v.status == 3 ? "" : "opacity:0.35;"}"></div>
                    </div>
                `);
                CaseCount[v.status] = CaseCount[v.status] + 1
            }
        }

        $(".waitcount").html(CaseCount[1]);
        $(".receivecount").html(CaseCount[2]);
        $(".finishcount").html(CaseCount[3]);
        $(".totalcount").html(CaseCount[1]+CaseCount[2]+CaseCount[3]);

        $(".getbtn").click(function (event) {
            let caseid = event.target.dataset.caseid
            if (caseid) {
                $.post('https://APEX-MedicReport/getcase', JSON.stringify({
                    caseid: caseid
                }));
                ClickSound.play();
            }
        })

        $(".gpsbtn").click(function (event) {
            let caseid = event.target.dataset.caseid
            if (caseid) {
                $.post('https://APEX-MedicReport/markGPS', JSON.stringify({
                    caseid: caseid
                }));
                ClickSound.play();
            }
        })

        $(".deletebtn").click(function (event) {
            let caseid = event.target.dataset.caseid
            let caseData = findCaseByCaseId(caseid)
            if (caseid && caseData && Number(caseData.status) === 3) {
                $.post('https://APEX-MedicReport/DeleteCase', JSON.stringify({
                    caseid: caseid
                }));
                ClickSound.play();
            }
        })

        filtersearch(search)

    }

    $("#searcase").on("keyup", function() {
        var value = $(this).val().toLowerCase();
        search = value
        filtersearch(search)
    });

    function filtersearch(text) {
        $(".casevalue").filter(function() {
            $(this).toggle($(this).text().toLowerCase().indexOf(text) > -1)
        });
    }

    // $(".removeall").click(function () {
    //     $.post('https://APEX-MedicReport/RemoveAll', JSON.stringify({}));
    //     ClickSound.play();
    // })

    document.onkeyup = function (data) {
        if (data.which == 27) {
            ToggleUI(false)
            $.post('https://APEX-MedicReport/exit', JSON.stringify({}));
        }

    };

    function print(data) {
        $.post('https://APEX-MedicReport/print', JSON.stringify({data:data}));
    }

    $(".checknoti").click(function (event) {
        if (Notify) {
            Notify = false
        } else {
            Notify = true
        }
        ClickSound.play();
        SetCheckBar(Notify)
    })

    function SetCheckBar(status) {
        if (status) {
            $(".checkcircle").css("left","0%");
            $(".checkbar").css("background-color","#00b2ff");
        } else {
            $(".checkcircle").css("left","50%");
            $(".checkbar").css("background-color","#525252");
        }
    }

     $(".checknormal").click(function (event) {
        if (casefilter.normal) {
            casefilter.normal = false
        } else {
            casefilter.normal = true
        }
        RefreshFilterUI()
    })

    $(".checkbodybag").click(function (event) {
        if (casefilter.bodybag) {
            casefilter.bodybag = false
        } else {
            casefilter.bodybag = true
        }
        RefreshFilterUI()
    })

    $(".checkwaiting").click(function (event) {
        if (casefilter.waiting) {
            casefilter.waiting = false
        } else {
            casefilter.waiting = true
        }
        RefreshFilterUI()
    })

    $(".checkbargoing").click(function (event) {
        if (casefilter.going) {
            casefilter.going = false
        } else {
            casefilter.going = true
        }
        RefreshFilterUI()
    })

    $(".checkbarsafe").click(function (event) {
        if (casefilter.safe) {
            casefilter.safe = false
        } else {
            casefilter.safe = true
        }
        RefreshFilterUI()
    })

    function RefreshFilterUI() {
        ClickSound.play();
        if (casefilter.normal) {
            $(".checkcirclenormal").css("left","0%");
            $(".checkbarnormal").css("background-color","#00b2ff");
        } else {
            $(".checkcirclenormal").css("left","50%");
            $(".checkbarnormal").css("background-color","#525252");
        }
        if (casefilter.bodybag) {
            $(".checkcirclebodybag").css("left","0%");
            $(".checkbarbodybag").css("background-color","#00b2ff");
        } else {
            $(".checkcirclebodybag").css("left","50%");
            $(".checkbarbodybag").css("background-color","#525252");
        }
        if (casefilter.waiting) {
            $(".checkcirclewaiting").css("left","0%");
            $(".checkbarwaiting").css("background-color","#00b2ff");
        } else {
            $(".checkcirclewaiting").css("left","50%");
            $(".checkbarwaiting").css("background-color","#525252");
        }
        if (casefilter.going) {
            $(".checkcirclegoing").css("left","0%");
            $(".checkbargoing").css("background-color","#00b2ff");
        } else {
            $(".checkcirclegoing").css("left","50%");
            $(".checkbargoing").css("background-color","#525252");
        }
        if (casefilter.safe) {
            $(".checkcirclesafe").css("left","0%");
            $(".checkbarsafe").css("background-color","#00b2ff");
        } else {
            $(".checkcirclesafe").css("left","50%");
            $(".checkbarsafe").css("background-color","#525252");
        }
        RefreshCaseList()
    }

    SetCheckBar(Notify)
    RefreshFilterUI()

    $(".addblacklistbtn").click(function (event) {
        let number = $("#blacklist").val();
        if (number) {
            $.post('https://APEX-MedicReport/addblacklistnumber', JSON.stringify({number:number,status:true}));
            $("#blacklist").val("")
            ClickSound.play();
        }
    })

    $(".deleteblacklistbtn").click(function (event) {
        let number = $("#blacklist").val();
        if (number) {
            $.post('https://APEX-MedicReport/addblacklistnumber', JSON.stringify({number:number,status:false}));
            $("#blacklist").val("")
            ClickSound.play();
        }
    })

    $(".toggleblacklist").click(function (event) {
        if (blacklistwindows) {
            blacklistwindows = false
            $(".blacklistwindows").hide();
            $(".toggleblacklist").html("BLACKLIST >");
        } else {
            blacklistwindows = true
            $(".blacklistwindows").show();
            $(".toggleblacklist").html("BLACKLIST <");
        }
        ClickSound.play();
    })

    // $(".removeall").click(function () {
    //     $.post('https://APEX-MedicReport/RemoveAll', JSON.stringify({}));
    //     ClickSound.play();
    // })

    const button = document.querySelector('.removeall');

    let holdTimeout;
    let progressInterval;
    let elapsedTime = 0;
    let isHolding = false;
    const holdDurationMs = 5000;

    const resetRemoveAllProgress = () => {
        clearTimeout(holdTimeout);
        clearInterval(progressInterval);
        ClickSound.pause();
        $(".loadremoveall").css({ "width": "0%" });
        isHolding = false;
    };

    if (button) {
        button.addEventListener('mousedown', () => {
            if (isHolding) return;
            isHolding = true;
            elapsedTime = 0;

            progressInterval = setInterval(() => {
                elapsedTime += 100;
                const progress = Math.min((elapsedTime / holdDurationMs) * 100, 100);
                $(".loadremoveall").css({ "width": `${progress.toFixed(2)}%` });
            }, 100);

            holdTimeout = setTimeout(() => {
                if (!isHolding) return;
                $.post('https://APEX-MedicReport/RemoveAll', JSON.stringify({}));
                ClickSound.play();
                resetRemoveAllProgress();
            }, holdDurationMs);
        });

        const stopHolding = () => {
            if (!isHolding) return;
            resetRemoveAllProgress();
        };

        button.addEventListener('mouseup', stopHolding);
        button.addEventListener('mouseleave', stopHolding);
    }

})
