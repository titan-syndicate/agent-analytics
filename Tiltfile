if k8s_context() != 'docker-desktop':
    fail('Use the docker-desktop Kubernetes context for this local-only lab.')

k8s_yaml('local/lgtm.yaml')
collector_config = str(read_file('local/collector.yaml'))
viewers = read_yaml_stream('local/viewers.yaml')
for obj in viewers:
    if obj['kind'] == 'Deployment' and obj['metadata']['name'] == 'collector':
        obj['spec']['template']['metadata']['annotations'] = {
            'agent-analytics/collector-config': collector_config,
        }
k8s_yaml(encode_yaml_stream(viewers))
k8s_yaml(encode_yaml({
    'apiVersion': 'v1',
    'kind': 'ConfigMap',
    'metadata': {'name': 'agent-analytics-collector', 'namespace': 'agent-analytics-lab'},
    'data': {'collector.yaml': collector_config},
}))
k8s_resource(
    'lgtm',
    port_forwards=[
        port_forward(3000, 3000, host='127.0.0.1'),
    ],
    links=[
        link('http://127.0.0.1:3000/explore', 'OTel viewer'),
    ],
)
k8s_resource('collector', port_forwards=[port_forward(4318, 4318, host='127.0.0.1')],
             resource_deps=['lgtm', 'phoenix', 'langfuse'])
k8s_resource('phoenix', port_forwards=[port_forward(6006, 6006, host='127.0.0.1')],
             links=[link('http://127.0.0.1:6006', 'Phoenix')])
k8s_resource('langfuse', port_forwards=[
    port_forward(3001, 3000, host='127.0.0.1'),
    port_forward(9090, 9002, host='127.0.0.1'),
], links=[link('http://127.0.0.1:3001', 'Langfuse')])
