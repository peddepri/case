import random
import time
from kubernetes import client, config

# Deletes a random pod in the target namespace matching a label selector
# Example: python chaos_kill_random_pod.py case app=backend

def main():
    import sys
    if len(sys.argv) < 3:
        print("Usage: chaos_kill_random_pod.py <namespace> <labelSelector>")
        sys.exit(1)

    ns = sys.argv[1]
    selector = sys.argv[2]

    try:
        config.load_incluster_config()
    except Exception:
        config.load_kube_config()

    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace=ns, label_selector=selector).items
    if not pods:
        print("No pods found for selector", selector)
        return
    victim = random.choice(pods)
    name = victim.metadata.name
    print(f"Deleting pod {name} in {ns}...")
    v1.delete_namespaced_pod(name=name, namespace=ns)
    # Optional: Wait a bit
    time.sleep(2)
    print("Pod deletion requested.")

if __name__ == "__main__":
    main()
