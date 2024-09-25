import glob
import os
from xml.etree import ElementTree as xml_tag

class BuildMosaicQML:
    """
    To generate one QML fraction file using all fractions from each biome.
    """

    def __init__(self):
        self.mainQmlFraction={}
        # location of this file, used as default data dir
        data_dir=os.path.realpath(os.path.dirname(__file__) + '/files/')
        # the location to read the QML file fractions
        self.DATA_DIR=os.getenv("DATA_DIR", data_dir)
        # the output file name
        self.FILE_NAME=os.getenv("FILE_NAME", "prodes_brasil")

    def __listQmlFractionFiles(self):
        allFractionFiles = []
        for filename in glob.iglob(f"{self.DATA_DIR}/**/*.sfl", recursive=True):
            allFractionFiles.append(filename)
        return allFractionFiles

    def __loadEntriesFromFile(self, filename):
        
        with open(filename, 'r') as file:
            stringList = file.readlines()
            aFraction = f"""
                            <data>
                                {stringList}
                            </data>
                            """
            self.__mergeIntoMain(aFraction=aFraction)

    def __mergeIntoMain(self, aFraction):
        xmlFraction=xml_tag.fromstring(aFraction)
        for child in xmlFraction:
            if child.attrib['value'] not in self.mainQmlFraction:
                paletteEntry=f"""<{child.tag} color="{child.attrib['color']}" label="{child.attrib['label']}" value="{child.attrib['value']}" alpha="{child.attrib['alpha']}"/>"""
                self.mainQmlFraction[int(child.attrib['value'])]=paletteEntry


    def buildAndSaveFile(self):

        file_name=f"{self.FILE_NAME}.sfl"
        try:
            if os.path.isdir(self.DATA_DIR):
                files=self.__listQmlFractionFiles()
                for f in files:
                    self.__loadEntriesFromFile(filename=f)
                
                path_dir=f"{self.DATA_DIR}"
                mainQmlFraction = dict(sorted(self.mainQmlFraction.items()))

                with open(os.path.join(path_dir, file_name), "w") as file_sfl:
                    for key in mainQmlFraction:
                        file_sfl.write(f"{mainQmlFraction[key]}\n")
        except Exception as e:
            print(f"Failure on store QML fragment.{e}")
        finally:
            print(f"Store QML fragment: {file_name}")


qml = BuildMosaicQML()
qml.buildAndSaveFile()