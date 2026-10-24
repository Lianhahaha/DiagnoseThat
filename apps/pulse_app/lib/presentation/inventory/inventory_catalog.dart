import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pulse_protocol/pulse_wire.dart';

/// Hierarchical Inventory browser catalog (UI navigation only).
class InventoryBrowserGroup {
  const InventoryBrowserGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.domains,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<InventoryDomainNode> domains;
}

class InventoryDomainNode {
  const InventoryDomainNode({
    required this.id,
    required this.label,
    required this.icon,
    required this.implemented,
  });

  final InventoryDomainId id;
  final String label;
  final IconData icon;
  final bool implemented;
}

const kInventoryBrowserGroups = <InventoryBrowserGroup>[
  InventoryBrowserGroup(
    id: 'system',
    label: 'System',
    icon: LucideIcons.server,
    domains: [
      InventoryDomainNode(
        id: InventoryDomainId.motherboard,
        label: 'Motherboard',
        icon: LucideIcons.circuitBoard,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.bios,
        label: 'BIOS',
        icon: LucideIcons.cpu,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.cpu,
        label: 'CPU',
        icon: LucideIcons.cpu,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.memoryModules,
        label: 'Memory',
        icon: LucideIcons.database,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.storage,
        label: 'Storage',
        icon: LucideIcons.database,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.networkAdapters,
        label: 'Network',
        icon: LucideIcons.globe,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.battery,
        label: 'Battery',
        icon: LucideIcons.zap,
        implemented: true,
      ),
    ],
  ),
  InventoryBrowserGroup(
    id: 'devices',
    label: 'Devices',
    icon: LucideIcons.usb,
    domains: [
      InventoryDomainNode(
        id: InventoryDomainId.usb,
        label: 'USB',
        icon: LucideIcons.usb,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.pci,
        label: 'PCI',
        icon: LucideIcons.circuitBoard,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.displays,
        label: 'Displays',
        icon: LucideIcons.monitor,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.audio,
        label: 'Audio',
        icon: LucideIcons.headphones,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.bluetooth,
        label: 'Bluetooth',
        icon: LucideIcons.radio,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.printers,
        label: 'Printers',
        icon: LucideIcons.fileText,
        implemented: true,
      ),
    ],
  ),
  InventoryBrowserGroup(
    id: 'software',
    label: 'Software',
    icon: LucideIcons.package,
    domains: [
      InventoryDomainNode(
        id: InventoryDomainId.software,
        label: 'Installed software',
        icon: LucideIcons.package,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.drivers,
        label: 'Drivers',
        icon: LucideIcons.cpu,
        implemented: true,
      ),
      InventoryDomainNode(
        id: InventoryDomainId.services,
        label: 'Services',
        icon: LucideIcons.cog,
        implemented: true,
      ),
    ],
  ),
];

InventoryDomainNode? inventoryNodeFor(InventoryDomainId id) {
  for (final group in kInventoryBrowserGroups) {
    for (final node in group.domains) {
      if (node.id == id) return node;
    }
  }
  return null;
}
