import QtQuick 2.0

pragma Singleton

// TODO make proper debug output and optimize
QtObject {
    id: incubator

    property int __batch: 0
    property var queue: ([])
    property var running: ([])
    property var done: ([])
    property bool asynchronous: true
    property bool debug: false

    readonly property Item __private: Item {
        id: __private
        Component { id: timerComponent; Timer {} }
        function setTimeout(callback, timeout)
        {
            var timer = timerComponent.createObject(__private)
            timer.interval = timeout || 0
            timer.triggered.connect(function()
            {
                timer.stop()
                timer.destroy()
                timer = null
                callback()
            })
            timer.start()
            return timer
        }
    }

    function now(input, parent, attributes, successCallback) {
        __toQueue(input, parent, attributes, successCallback)
        incubate()
    }

    function later(input, parent, attributes, successCallback){
        __toQueue(input, parent, attributes, successCallback)
    }

    function incubate() {
        for(var qid in queue) {
            if(queue[qid]) {
                running.push(queue[qid])
                if(asynchronous)
                    queue[qid].go()
            }
        }

        if(!asynchronous && running.length > 0) {
            // NOTE nasty hack to avoid "QQmlComponent: Cannot create new component instance before completing the previous" error messages - when things get hot.
            __private.setTimeout(function(){
                if(incubator.running.length > 0)
                    incubator.running.pop().go()
            },1)
        }

        queue = []
        __batch++
    }

    function __done(id) {
        done.push(id)
        if(!asynchronous && running.length > 0) {

            running.pop().go()
        }
    }

    function __toQueue(input, parent, attributes, successCallback) {

        //console.log('input is?',input.toString(),typeof input,Object.prototype.toString.call(input))

        var type = (typeof input)

        var queueObject

        if(type == 'string') {
            // Determine if raw qml string or url
            if(input.indexOf("Component") > -1) {
                var c = Qt.createQmlObject(input, parent, "Incubator.qml-object_from_string")
                queueObject = this.fromComponent(c,parent,attributes,successCallback)
            } else {
                queueObject = this.fromComponent(Qt.createComponent(input),parent,attributes,successCallback)
            }
        } else if(type == 'object') {
            type = input.toString()
            if(startsWith(type,"QQmlComponent"))
                queueObject = this.fromComponent(input,parent,attributes,successCallback)
            else
                throw 'Unknown input "'+input+'" of type "'+type+'"'
        } else {
            throw 'Unknown input "'+input+'" of type "'+type+'"'
        }

        return queueObject

    }

    function fromComponent(component, parent, attributes, successCallback) {

        var incubatorInstance = this

        var qo = {}
        qo.id = incubator.queue.length
        qo.batch = __batch
        qo.component = component
        qo.incubator = undefined
        qo.parent = parent
        qo.attributes = attributes || {}
        qo.onSuccess = successCallback || function(){}

        qo.componentStatusCallback = function(){
            var that = this

//            if(debug) console.debug('Incubator','queue object','componentStatusCallback',this.id) //¤qakdbg

            if(this.component.status === Component.Ready) {

                if(!incubator.asynchronous) {
                    var createdObject = this.component.createObject(this.parent, this.attributes)
                    that.onSuccess(createdObject)
//                    if(debug) console.debug('Incubator','queue object','created', that.id, createdObject) //¤qakdbg
                    incubator.__done(that.id)
                } else {
                    this.incubator = this.component.incubateObject(this.parent, this.attributes, Qt.Asynchronous)

                    var incubatorStatusCallback = function(){
//                        if(debug) console.debug('Incubator','queue object','incubatorStatusCallback',that.id) //¤qakdbg

                        var status = that.incubator.status

                        if(Component && status === Component.Ready) {
                            that.onSuccess(that.incubator.object)
//                            if(debug) console.debug('Incubator','queue object','incubated', that.id, that.incubator.object) //¤qakdbg
                            incubator.__done(that.id)
                            //delete incubator.queue[that.id]
                        } else {
                            if(status === Component.Null)
                                console.error('Incubator','status',status,'(Null)',that.incubator.errorString)
                            if(status === Component.Error)
                                console.error('Incubator','status',status,'(Error)',that.incubator.errorString)
                            throw 'incubation error '+status
                        }
                    }

                    if(this.incubator.status !== Component.Ready) {
                        this.incubator.onStatusChanged = incubatorStatusCallback
                    } else {
                        incubatorStatusCallback()
                    }
                }

            } else if (this.component.status === Component.Error) {
                throw "Error loading component in callback " + this.component.errorString()
            } else {
                throw "Error unknown component status (in callback) " + this.component.status
            }
        }

        qo.go = function() {
//            if(debug) console.debug('Incubator','queue object','.go', this.id, this.batch) //¤qakdbg

            if(this.component.status === Component.Ready)
                this.componentStatusCallback()
            else {
                if(this.component.status === Component.Error) {
                    throw "Error loading component "+this.component.errorString()
                }

                if(this.component.status === undefined) {
                    throw "Error loading component (status undefined) "+this.component.status
                }

                this.component.statusChanged.connect(this.componentStatusCallback);
            }
        }

        incubator.queue.unshift(qo)

        return qo
    }

    function wrapAsComponent(qml) {
        qml = qml.replace(/([A-Z]+\S+ *\{[^}]+\})/, "Component { $1 ")+'}'
        //console.log(qml)
        return qml
    }

    function startsWith (haystack, needle) {
        return haystack.lastIndexOf(needle, 0) === 0
    }

}
