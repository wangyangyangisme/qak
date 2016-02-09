import QtQuick 2.5

import "./" as Qage
/*
 *
 */
Entity {
    id: sprite

    useAdaptiveSource: !enabled

    property bool enabled: true

    property string prefix: ""

    property bool ignore: false

    property bool error: false

    property Image currentFrame
    property int currentFrameIndex: 0
    property int currentSequenceFrameIndex: 0
    property int currentFrameDelay: defaultFrameDelay
    property int defaultFrameDelay: 40

    property int activeSequenceIndex: 0
    property var activeSequence

    // TODO
    property var sequenceNameIndex: {
        "sit":0,
        "sit > reach":1,
        "reach > sit":2,
        "sit > look_back":3,
        "look_back > sit":4
    }

    property var sequences: [
        {
            name: "sit",
            frames: [0],
            duration: 2000,
            to: { "sit": 1, "sit > look_back": 2, "sit > reach": 3 }
        },
        {
            name: "sit > reach",
            duration: 100,
            frames: [0,1,2,3,4,5],
            to: { "reach > sit": 1 }
        },
        {
            name: "reach > sit",
            duration: 100,
            frames: [5,4,3,2,1,0],
            to: { "sit": 1 }
        },
        {
            name: "sit > look_back",
            duration: 100,
            frames: [19,20,21,22,23],
            to: { "look_back > sit":1 }
        },
        {
            name: "look_back > sit",
            duration: 100,
            frames: [23,22,21,20,19],
            to: { "sit":1 }
        }
    ]

    function getSourceStepURL(step) {
        var src = ""

        if(step == 0) {
            src = source
        } else {
            src = source.substring(0, source.lastIndexOf(".")) + ".x" + step + source.substring(source.lastIndexOf("."))
        }

        var pfx = ""
        if(prefix !== '')
            pfx = prefix.replace(/\/+$/, "")+"/"

        // TODO do platform asset protocol control etc..
        if(src && src != "")
            src = "qrc:///"+pfx+src

        return src
    }

    Timer {
        id: animControl
        interval: currentFrameDelay
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {



            //
            if(!activeSequence) {
                activeSequence = sequences[activeSequenceIndex]
            }

            // Figure our how long this frame should show
            if('duration' in activeSequence) {
                // NOTE TODO TIMER? once the animation is started parameters can't be changed on it
                // So if anything changes the animation must be restarted
                if(currentFrameDelay != activeSequence.duration) {
                    currentFrameDelay = activeSequence.duration
                    //animControl.restart()
                }
            } else {
                if(currentFrameDelay != defaultFrameDelay) {
                    currentFrameDelay = defaultFrameDelay
                    //animControl.restart()
                }
            }

            // Show the frame
            db('Now playing',activeSequence.name,'at frame index',currentFrameIndex)
            currentFrame = repeater.itemAt(currentFrameIndex)

            // Figure out next frame
            if('frames' in activeSequence && Object.prototype.toString.call( activeSequence.frames ) === '[object Array]') {

                /*
                    Logic
                */

                var endSequenceFrameIndex = activeSequence.frames[activeSequence.frames.length-1]



                if(currentFrameIndex == endSequenceFrameIndex) {
                    db('End of sequence',activeSequence.name,'at index',currentSequenceFrameIndex,'- Deciding next sequence...')
                    currentSequenceFrameIndex = 0

                    if('to' in activeSequence) {
                        var seqTo = activeSequence.to
                        var nSeq = ""
                        var totalWeight = 0, cumWeight = 0
                        for(var seqName in seqTo) {
                            totalWeight += seqTo[seqName]
                        }
                        var randInt = Math.floor(Math.random()*totalWeight)

                        for(var seqName in seqTo) {
                            cumWeight += seqTo[seqName]
                            if (randInt < cumWeight) {
                                nSeq = seqName
                                break;
                            }

                        }


                        activeSequenceIndex = sequenceNameIndex[nSeq]


                        // TODO more sanity checks
                        if('length' in sequences && sequences.length > 0) {
                            activeSequence = sequences[activeSequenceIndex]
                            if(!activeSequence)
                                error('ActiveSequence is bullshit')
                        } else {
                            error('Sprite','something wrong')
                            return
                        }


                        //currentFrameIndex = activeSequence.frames[currentSequenceFrameIndex]
                        db('Next sequence',nSeq,'('+activeSequenceIndex+')','weight',totalWeight,'randInt',randInt)
                        currentFrameIndex = activeSequence.frames[currentSequenceFrameIndex]
                        return

                    }
                } else
                    currentSequenceFrameIndex++
                //db(activeSequence,activeSequence.frames,currentSequenceFrameIndex,endSequenceFrameIndex,activeSequence.frames[currentSequenceFrameIndex])
                //if(!activeSequence.frames[currentSequenceFrameIndex])
                //    db(activeSequence,activeSequence.frames,currentSequenceFrameIndex,endSequenceFrameIndex,activeSequence.frames[currentSequenceFrameIndex])
                currentFrameIndex = activeSequence.frames[currentSequenceFrameIndex]
                //db()
            } else {
                error('No frames. Skipping...')
            }

            //if(currentFrameIndex >= repeater.count-1 || currentFrameIndex < 0) {
            //    currentFrameIndex = 0
            //    warn('Corrected currentFrameIndex')
            //}

            //db('Sprite','next frame',currentFrameIndex)

        }

    }

    function pad(number, digits) {
        return new Array(Math.max(digits - String(number).length + 1, 0)).join(0) + number
    }

    onSourceChanged: {
        if(!enabled)
            return

        error = false
        ignore = false

        if(source == "" || !source) {
            db(sprite,'Empty source given')
            return
        }

        var path = getSourceStepURL(0)

        if(!resource.exists(path)) {
            warn('No resource',path,'found. Ignoring')
            error = true
            ignore = true
            return
        }

        // Match any '.<digit>.' entries
        var match = source.match('(\\.?\\d+?\\.)')
        match = match ? match[1] : false

        if(match !== false) {
            var number = match.replace('.', '')
            var digit = parseInt(number,10)
            var next = pad((digit+1),number.length)
            var nextMatch = source.replace(number, next)
            //nextMatch =
            log('Assuming animation source based on','"'+number+'"',nextMatch)
        } else {
            log('Assuming single image source')
            enabled = false
            return
        }

        //mapSource = path

    }

    Repeater {
       id: repeater
       model: 24
       Qage.Image {
           id: image

           asynchronous: true

           width: sprite.width
           height: sprite.height
           source: "sitting_man/" + pad((index+1),4) + ".png"
           sourceSize: Qt.size(width,height)
           visible: image == currentFrame
           //property int frame: index+1
       }
   }

}