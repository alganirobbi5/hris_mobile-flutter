class ProfileAvatarEntry {
  const ProfileAvatarEntry({
    required this.id,
    required this.name,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String assetPath;
}

class ProfileAvatarCatalog {
  ProfileAvatarCatalog._();

  static const List<ProfileAvatarEntry> all = <ProfileAvatarEntry>[
    ProfileAvatarEntry(
      id: '01-andi',
      name: 'Andi',
      assetPath: 'assets/avatars/01-andi.png',
    ),
    ProfileAvatarEntry(
      id: '02-sari',
      name: 'Sari',
      assetPath: 'assets/avatars/02-sari.png',
    ),
    ProfileAvatarEntry(
      id: '03-budi',
      name: 'Budi',
      assetPath: 'assets/avatars/03-budi.png',
    ),
    ProfileAvatarEntry(
      id: '04-rina',
      name: 'Rina',
      assetPath: 'assets/avatars/04-rina.png',
    ),
    ProfileAvatarEntry(
      id: '05-dimas',
      name: 'Dimas',
      assetPath: 'assets/avatars/05-dimas.png',
    ),
    ProfileAvatarEntry(
      id: '06-nadia',
      name: 'Nadia',
      assetPath: 'assets/avatars/06-nadia.png',
    ),
    ProfileAvatarEntry(
      id: '07-fajar',
      name: 'Fajar',
      assetPath: 'assets/avatars/07-fajar.png',
    ),
    ProfileAvatarEntry(
      id: '08-laras',
      name: 'Laras',
      assetPath: 'assets/avatars/08-laras.png',
    ),
  ];

  static ProfileAvatarEntry? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final ProfileAvatarEntry entry in all) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
