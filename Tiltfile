if k8s_context() != 'docker-desktop':
    fail('Use the docker-desktop Kubernetes context for this local-only lab.')

k8s_yaml('local/lgtm.yaml')
k8s_resource(
    'lgtm',
    port_forwards=[
        port_forward(3000, 3000, host='127.0.0.1'),
        port_forward(4318, 4318, host='127.0.0.1'),
    ],
    links=[
        link('http://127.0.0.1:3000/explore', 'OTel viewer'),
    ],
)
