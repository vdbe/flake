_: {
  boot = {
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];
    kernelModules = [
      "vfio"
      "vfio_iommu_type1"
      "vfio_pci"
    ];

    # TODO: extract all this info from micrvom.vm's
    extraModprobeConfig = ''
      options vfio-pci ids=10ec:8161
    '';
    # TODO: rewrite this with udev's so hotplug also not get unbound
    initrd.postDeviceCommands = ''
      echo 0000:02:00.0 > /sys/bus/pci/devices/0000:02:00.0/driver/unbind
    '';
  };
}
