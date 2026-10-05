def sa($k;$v): {key:$k,value:{stringValue:$v}};
def ia($k;$v): {key:$k,value:{intValue:($v|tostring)}};
def id($n): ($prefix + ("0000"+($n|tostring))[-4:]);
def span($number;$parent;$name;$operation;$agent;$start;$end;$extra;$status):
  {traceId:$trace,spanId:id($number),name:$name,kind:1,
   startTimeUnixNano:($start*1e9|tostring),endTimeUnixNano:($end*1e9|tostring),
   status:{code:$status},
   attributes:([sa("gen_ai.operation.name";$operation),
     sa("gen_ai.agent.name";$agent),sa("gen_ai.conversation.id";($run+"-"+.slug)),
     sa("agent_analytics.demo.run";$run),sa("agent_analytics.demo.scenario";.slug),
     sa("agent_analytics.demo.outcome";.outcome)] + $extra)}
   + (if $parent == null then {} else {parentSpanId:id($parent)} end);
. as $s | ($now - 60) as $start |
{
 resourceSpans:[{
  resource:{attributes:[sa("service.name";"agent-cost-demo"),
    sa("deployment.environment.name";"synthetic-demo"),
    sa("agent_analytics.demo.run";$run),sa("agent_analytics.demo.scenario";.slug)]},
  scopeSpans:[{scope:{name:"agent-analytics.synthetic-fixtures",version:"1"},spans:(
   [span(1;null;("DEMO "+.title);"invoke_agent";"coordinator";$start;($start+.seconds);
     [sa("agent_analytics.demo.synthetic";"true")];1)]
   + [range(1;.agents) as $i | span(10+$i;1;("DEMO worker "+($i|tostring));
       "invoke_agent";("worker-"+($i|tostring));($start+1);($start+.seconds-1);[];1)]
   + [range(0;(.input|length)) as $i |
      (if $s.agents>1 and $i>0 and $i<4 then 10+$i else 1 end) as $parent |
      span(100+$i;$parent;("DEMO model call "+($i+1|tostring));"chat";
        (if $parent>1 then "worker-"+($i|tostring) else "coordinator" end);
        ($start+1+$i);($start+2+$i);
        [sa("gen_ai.request.model";.model),sa("gen_ai.response.model";.model),
         ia("gen_ai.usage.input_tokens";.input[$i]),ia("gen_ai.usage.output_tokens";.output[$i])];1)]
   + [range(0;.tools) as $i |
      span(200+$i;1;("DEMO test command "+($i+1|tostring));"execute_tool";"coordinator";
        ($start+2+$i);($start+3+$i);
        [sa("gen_ai.tool.name";"demo-test-runner"),
         sa("agent_analytics.demo.tool_result";(if $i < .failed then "runner unavailable" else "passed" end))];
        (if $i < .failed then 2 else 1 end))]
  )}]
 }]
}
