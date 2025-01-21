class RingBuffer{constructor(e,t,n){this.buffer=e,this.avail=t,this.threads=n,this.rpos=0,this.wpos=0}data_left(){return this.threads?Atomics.load(this.avail,0):this.avail}space_left(){return this.buffer.length-this.data_left()}read(e){const n=this.buffer.length;let s=0,t=e.length;if(this.rpos+t>n){const o=n-this.rpos;e.set(this.buffer.subarray(this.rpos,n)),s=o,t-=o,this.rpos=0}t&&e.set(this.buffer.subarray(this.rpos,this.rpos+t),s),this.rpos+=t,this.threads?(Atomics.add(this.avail,0,-e.length),Atomics.notify(this.avail,0)):this.avail-=e.length}write(e){const t=e.length,n=this.buffer.length-this.wpos;if(n>=t)this.buffer.set(e,this.wpos),this.wpos+=t,n===t&&(this.wpos=0);else{const s=e.subarray(0,n),t=e.subarray(n);this.buffer.set(s,this.wpos),this.buffer.set(t),this.wpos=t.length}this.threads?(Atomics.add(this.avail,0,t),Atomics.notify(this.avail,0)):this.avail+=t}}class GodotProcessor extends AudioWorkletProcessor{constructor(){super(),this.threads=!1,this.running=!0,this.lock=null,this.notifier=null,this.output=null,this.output_buffer=new Float32Array,this.input=null,this.input_buffer=new Float32Array,this.port.onmessage=e=>{const t=e.data.cmd,n=e.data.data;this.parse_message(t,n)}}process_notify(){this.notifier&&(Atomics.add(this.notifier,0,1),Atomics.notify(this.notifier,0))}parse_message(e,t){if(e==="start"&&t){const n=t[0];let e=0;this.threads=!0,this.lock=n.subarray(e,++e),this.notifier=n.subarray(e,++e);const s=n.subarray(e,++e),o=n.subarray(e,++e);this.input=new RingBuffer(t[1],s,!0),this.output=new RingBuffer(t[2],o,!0)}else e==="stop"?(this.running=!1,this.output=null,this.input=null,this.lock=null,this.notifier=null):e==="start_nothreads"?this.output=new RingBuffer(t[0],t[0].length,!1):e==="chunk"&&this.output.write(t)}static array_has_data(e){return e.length&&e[0].length&&e[0][0].length}process(e,t){if(!this.running)return!1;if(this.output===null)return!0;const s=GodotProcessor.array_has_data(e);if(s){const t=e[0],n=t[0].length*t.length;this.input_buffer.length!==n&&(this.input_buffer=new Float32Array(n)),this.threads?this.input.space_left()>=n&&(GodotProcessor.write_input(this.input_buffer,t),this.input.write(this.input_buffer)):(GodotProcessor.write_input(this.input_buffer,t),this.port.postMessage({cmd:"input",data:this.input_buffer}))}const o=GodotProcessor.array_has_data(t);if(o){const n=t[0],e=n[0].length*n.length;this.output_buffer.length!==e&&(this.output_buffer=new Float32Array(e)),this.output.data_left()>=e&&(this.output.read(this.output_buffer),GodotProcessor.write_output(n,this.output_buffer),this.threads||this.port.postMessage({cmd:"read",data:e}))}return this.process_notify(),!0}static write_output(e,t){const n=e.length;for(let s=0;s<n;s++)for(let o=0;o<e[s].length;o++)e[s][o]=t[o*n+s]}static write_input(e,t){const n=t.length;for(let s=0;s<n;s++)for(let o=0;o<t[s].length;o++)e[o*n+s]=t[s][o]}}registerProcessor("godot-processor",GodotProcessor)