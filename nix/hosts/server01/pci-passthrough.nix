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
  };
}
