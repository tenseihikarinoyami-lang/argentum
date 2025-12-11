"""
╔═════════════════════════════════════════════════════════════════════════════╗
║                     SISTEMA DE RESTAURACIÓN DE BACKUP                       ║
║                                                                             ║
║  Este script protege tu configuración actual antes de aplicar mejoras.     ║
║  Si algo falla, puedes restaurar el estado anterior con un simple click.   ║
║                                                                             ║
╚═════════════════════════════════════════════════════════════════════════════╝
"""

import json
import os
import shutil
from datetime import datetime
from typing import Dict, List, Any
import hashlib

class BackupRestoration:
    """Sistema de backup y restauración para el trading bot."""
    
    def __init__(self):
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.backup_dir = os.path.join(self.base_dir, 'BACKUPS')
        self.critical_files = [
            'config.json',
            'signal_generator.py',
            'main.py',
            'account_risk_manager.py',
            'position_sizer.py',
            'web_interface.py',
            'trading_signals.db'
        ]
        
        # Crear directorio de backups si no existe
        if not os.path.exists(self.backup_dir):
            os.makedirs(self.backup_dir)
            print(f"[OK] Directorio de backups creado: {self.backup_dir}")
    
    def create_backup(self, backup_name: str = None) -> str:
        """
        Crear un backup completo de la configuración actual.
        
        Args:
            backup_name: Nombre personalizado del backup (ej: 'antes_mejoras_v2')
        
        Returns:
            Ruta del backup creado
        """
        if backup_name is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"backup_{timestamp}"
        
        backup_path = os.path.join(self.backup_dir, backup_name)
        
        if os.path.exists(backup_path):
            print(f"[WARNING] Backup ya existe: {backup_name}")
            return backup_path
        
        os.makedirs(backup_path)
        
        metadata = {
            'timestamp': datetime.now().isoformat(),
            'backup_name': backup_name,
            'files_backed_up': [],
            'file_hashes': {},
            'total_size_bytes': 0
        }
        
        print(f"\n📦 Creando backup: {backup_name}")
        print("=" * 70)
        
        for filename in self.critical_files:
            source_path = os.path.join(self.base_dir, filename)
            
            if not os.path.exists(source_path):
                print(f"⚠️  Archivo no encontrado (será omitido): {filename}")
                continue
            
            dest_path = os.path.join(backup_path, filename)
            
            if os.path.isfile(source_path):
                shutil.copy2(source_path, dest_path)
                file_size = os.path.getsize(dest_path)
                file_hash = self._calculate_hash(dest_path)
                
                metadata['files_backed_up'].append(filename)
                metadata['file_hashes'][filename] = file_hash
                metadata['total_size_bytes'] += file_size
                
                print(f"✓ {filename:30s} ({file_size:>10,} bytes) [HASH: {file_hash[:8]}...]")
            
            elif os.path.isdir(source_path) and filename.endswith('.db'):
                shutil.copytree(source_path, dest_path)
                print(f"✓ {filename:30s} (BASE DE DATOS) [BACKED UP]")
        
        # Guardar metadata
        metadata_path = os.path.join(backup_path, 'METADATA.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print("=" * 70)
        print(f"✅ BACKUP COMPLETADO")
        print(f"   Ubicación: {backup_path}")
        print(f"   Archivos: {len(metadata['files_backed_up'])}")
        print(f"   Tamaño total: {metadata['total_size_bytes'] / 1024 / 1024:.2f} MB")
        print(f"   Timestamp: {metadata['timestamp']}")
        
        return backup_path
    
    def list_backups(self) -> List[Dict[str, Any]]:
        """
        Listar todos los backups disponibles.
        
        Returns:
            Lista de información de backups
        """
        backups = []
        
        if not os.path.exists(self.backup_dir):
            print("❌ No hay backups creados aún.")
            return backups
        
        for backup_name in sorted(os.listdir(self.backup_dir)):
            backup_path = os.path.join(self.backup_dir, backup_name)
            metadata_path = os.path.join(backup_path, 'METADATA.json')
            
            if os.path.isfile(metadata_path):
                with open(metadata_path, 'r') as f:
                    metadata = json.load(f)
                    backups.append({
                        'name': backup_name,
                        'path': backup_path,
                        'timestamp': metadata.get('timestamp'),
                        'files': len(metadata.get('files_backed_up', [])),
                        'size_mb': metadata.get('total_size_bytes', 0) / 1024 / 1024
                    })
        
        return backups
    
    def restore_backup(self, backup_name: str, confirm: bool = True) -> bool:
        """
        Restaurar un backup anterior.
        
        Args:
            backup_name: Nombre del backup a restaurar
            confirm: Pedir confirmación antes de restaurar
        
        Returns:
            True si la restauración fue exitosa, False si falló
        """
        backup_path = os.path.join(self.backup_dir, backup_name)
        
        if not os.path.exists(backup_path):
            print(f"❌ Backup no encontrado: {backup_name}")
            return False
        
        metadata_path = os.path.join(backup_path, 'METADATA.json')
        if not os.path.isfile(metadata_path):
            print(f"❌ Metadata no encontrada en backup: {backup_name}")
            return False
        
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        print(f"\n⚠️  RESTAURACIÓN DE BACKUP: {backup_name}")
        print("=" * 70)
        print(f"Timestamp: {metadata['timestamp']}")
        print(f"Archivos a restaurar: {len(metadata['files_backed_up'])}")
        
        if confirm:
            response = input("¿Estás seguro? (s/n): ").lower().strip()
            if response != 's':
                print("❌ Restauración cancelada.")
                return False
        
        print("\nRestaurando...")
        print("=" * 70)
        
        errors = []
        for filename in metadata['files_backed_up']:
            source_path = os.path.join(backup_path, filename)
            dest_path = os.path.join(self.base_dir, filename)
            
            try:
                if os.path.isfile(source_path):
                    # Crear backup del archivo actual antes de sobrescribir
                    if os.path.exists(dest_path):
                        temp_backup = dest_path + '.pre_restore'
                        shutil.copy2(dest_path, temp_backup)
                    
                    shutil.copy2(source_path, dest_path)
                    
                    # Verificar integridad
                    current_hash = self._calculate_hash(dest_path)
                    expected_hash = metadata['file_hashes'].get(filename)
                    
                    if current_hash == expected_hash:
                        print(f"✓ {filename:30s} [VERIFICADO]")
                    else:
                        print(f"⚠️  {filename:30s} [Hash mismatch - posible corrupción]")
                        errors.append(f"Hash mismatch en {filename}")
            
            except Exception as e:
                print(f"❌ {filename:30s} [ERROR: {str(e)}]")
                errors.append(f"Error restaurando {filename}: {str(e)}")
        
        print("=" * 70)
        
        if errors:
            print(f"⚠️  RESTAURACIÓN COMPLETADA CON ERRORES:")
            for error in errors:
                print(f"   - {error}")
            return False
        else:
            print(f"✅ RESTAURACIÓN COMPLETADA EXITOSAMENTE")
            return True
    
    def verify_backup(self, backup_name: str) -> bool:
        """
        Verificar integridad de un backup.
        
        Args:
            backup_name: Nombre del backup a verificar
        
        Returns:
            True si la integridad es correcta, False si hay problemas
        """
        backup_path = os.path.join(self.backup_dir, backup_name)
        metadata_path = os.path.join(backup_path, 'METADATA.json')
        
        if not os.path.isfile(metadata_path):
            print(f"❌ Metadata no encontrada para: {backup_name}")
            return False
        
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        print(f"\n🔍 Verificando integridad del backup: {backup_name}")
        print("=" * 70)
        
        all_ok = True
        for filename, expected_hash in metadata['file_hashes'].items():
            file_path = os.path.join(backup_path, filename)
            
            if not os.path.exists(file_path):
                print(f"❌ {filename:30s} [ARCHIVO FALTANTE]")
                all_ok = False
                continue
            
            current_hash = self._calculate_hash(file_path)
            if current_hash == expected_hash:
                print(f"✓ {filename:30s} [OK]")
            else:
                print(f"❌ {filename:30s} [CORRUPTED - Hash mismatch]")
                all_ok = False
        
        print("=" * 70)
        
        if all_ok:
            print("✅ BACKUP ÍNTEGRO - Listo para restaurar")
        else:
            print("❌ BACKUP DAÑADO - No se recomienda restaurar")
        
        return all_ok
    
    def _calculate_hash(self, file_path: str, algorithm: str = 'sha256') -> str:
        """
        Calcular hash de un archivo.
        
        Args:
            file_path: Ruta del archivo
            algorithm: Algoritmo de hash (default: sha256)
        
        Returns:
            Hash en formato hexadecimal
        """
        hasher = hashlib.new(algorithm)
        
        with open(file_path, 'rb') as f:
            while True:
                chunk = f.read(8192)
                if not chunk:
                    break
                hasher.update(chunk)
        
        return hasher.hexdigest()
    
    def cleanup_old_backups(self, keep_last_n: int = 5) -> int:
        """
        Eliminar backups antiguos, manteniendo solo los más recientes.
        
        Args:
            keep_last_n: Número de backups más recientes a mantener
        
        Returns:
            Número de backups eliminados
        """
        backups = self.list_backups()
        
        if len(backups) <= keep_last_n:
            print(f"ℹ️  Tienes {len(backups)} backups. Nada que limpiar.")
            return 0
        
        # Ordenar por fecha (más antiguos primero)
        sorted_backups = sorted(backups, key=lambda x: x['timestamp'])
        to_delete = sorted_backups[:-keep_last_n]
        
        print(f"\n🧹 Limpiando backups antiguos...")
        print(f"   Manteniendo los {keep_last_n} más recientes")
        print("=" * 70)
        
        deleted_count = 0
        freed_space = 0
        
        for backup in to_delete:
            try:
                shutil.rmtree(backup['path'])
                freed_space += backup['size_mb']
                deleted_count += 1
                print(f"✓ Eliminado: {backup['name']} ({backup['size_mb']:.2f} MB)")
            except Exception as e:
                print(f"❌ Error eliminando {backup['name']}: {str(e)}")
        
        print("=" * 70)
        print(f"✅ LIMPIEZA COMPLETADA")
        print(f"   Backups eliminados: {deleted_count}")
        print(f"   Espacio liberado: {freed_space:.2f} MB")
        
        return deleted_count


def main():
    """Menú principal del sistema de restauración."""
    
    system = BackupRestoration()
    
    while True:
        print("\n" + "=" * 70)
        print("🔐 SISTEMA DE RESTAURACIÓN DE BACKUP")
        print("=" * 70)
        print("1. 📦 Crear nuevo backup")
        print("2. 📋 Listar backups disponibles")
        print("3. 🔄 Restaurar backup")
        print("4. 🔍 Verificar integridad de backup")
        print("5. 🧹 Limpiar backups antiguos")
        print("6. ❌ Salir")
        print("=" * 70)
        
        choice = input("Selecciona una opción (1-6): ").strip()
        
        if choice == '1':
            backup_name = input("Nombre del backup (Enter para auto-generar): ").strip()
            if backup_name:
                system.create_backup(backup_name)
            else:
                system.create_backup()
        
        elif choice == '2':
            backups = system.list_backups()
            if backups:
                print("\n📦 BACKUPS DISPONIBLES:")
                print("=" * 70)
                for i, backup in enumerate(backups, 1):
                    print(f"{i}. {backup['name']}")
                    print(f"   Timestamp: {backup['timestamp']}")
                    print(f"   Archivos: {backup['files']}")
                    print(f"   Tamaño: {backup['size_mb']:.2f} MB")
                    print()
        
        elif choice == '3':
            backups = system.list_backups()
            if not backups:
                print("❌ No hay backups disponibles.")
                continue
            
            print("\n📦 BACKUPS DISPONIBLES:")
            for i, backup in enumerate(backups, 1):
                print(f"{i}. {backup['name']}")
            
            backup_idx = input("\nSelecciona el número del backup a restaurar: ").strip()
            try:
                idx = int(backup_idx) - 1
                if 0 <= idx < len(backups):
                    system.restore_backup(backups[idx]['name'])
                else:
                    print("❌ Índice inválido.")
            except ValueError:
                print("❌ Entrada inválida.")
        
        elif choice == '4':
            backups = system.list_backups()
            if not backups:
                print("❌ No hay backups disponibles.")
                continue
            
            print("\n📦 BACKUPS DISPONIBLES:")
            for i, backup in enumerate(backups, 1):
                print(f"{i}. {backup['name']}")
            
            backup_idx = input("\nSelecciona el número del backup a verificar: ").strip()
            try:
                idx = int(backup_idx) - 1
                if 0 <= idx < len(backups):
                    system.verify_backup(backups[idx]['name'])
                else:
                    print("❌ Índice inválido.")
            except ValueError:
                print("❌ Entrada inválida.")
        
        elif choice == '5':
            keep = input("¿Cuántos backups recientes mantener? (default: 5): ").strip()
            keep_n = int(keep) if keep.isdigit() else 5
            system.cleanup_old_backups(keep_n)
        
        elif choice == '6':
            print("\n✅ Saliendo...")
            break
        
        else:
            print("❌ Opción inválida. Intenta de nuevo.")


if __name__ == "__main__":
    print("\n╔═════════════════════════════════════════════════════════════════════════════╗")
    print("║              SISTEMA DE BACKUP Y RESTAURACIÓN - TRADING BOT                ║")
    print("║                                                                             ║")
    print("║  ⚠️  IMPORTANTE: Crea un backup ANTES de aplicar cualquier mejora          ║")
    print("║  Si algo falla, podrás restaurar tu configuración anterior en segundos    ║")
    print("║                                                                             ║")
    print("╚═════════════════════════════════════════════════════════════════════════════╝\n")
    
    main()
