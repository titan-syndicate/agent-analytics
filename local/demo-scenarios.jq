# Deliberately invented examples, not Copilot benchmarks or price estimates.
[
 {slug:"baseline",title:"A scoped fix",task:"small_fix",outcome:"accepted (fixture)",input:[4000,6000],output:[200,300],agents:1,tools:1,failed:0,seconds:8,model:"demo-small"},
 {slug:"context",title:"Repeated broad context",task:"small_fix",outcome:"accepted (fixture)",input:[8000,24000,48000,80000],output:[250,250,300,300],agents:1,tools:3,failed:0,seconds:25,model:"demo-small"},
 {slug:"output",title:"Verbose output",task:"small_fix",outcome:"accepted (fixture)",input:[4000,6000],output:[3000,6000],agents:1,tools:1,failed:0,seconds:24,model:"demo-small"},
 {slug:"retry",title:"Broken test harness retries",task:"small_fix",outcome:"unknown (fixture)",input:[6000,9000,14000,20000,26000],output:[200,200,200,200,400],agents:1,tools:5,failed:4,seconds:30,model:"demo-small"},
 {slug:"fanout",title:"One prompt, several agents",task:"small_fix",outcome:"accepted (fixture)",input:[6000,10000,10000,10000,18000],output:[300,400,400,400,500],agents:4,tools:3,failed:0,seconds:22,model:"demo-small"},
 {slug:"routing",title:"Larger resolved model",task:"small_fix",outcome:"accepted (fixture)",input:[4000,6000],output:[200,300],agents:1,tools:1,failed:0,seconds:12,model:"demo-large"}
]
