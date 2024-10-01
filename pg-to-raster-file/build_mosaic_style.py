import glob
import os
from xml.etree import ElementTree as xml_tag

class BuildMosaicStyle:
    """
    To generate one QML and one SLD fraction file using all fractions from each biome.
    """

    def __init__(self):
        self.types=['sfl','sldf']
        # location of this file, used as default data dir
        data_dir=os.path.realpath(os.path.dirname(__file__) + '/files/')
        # the location to read the QML file fractions
        self.DATA_DIR=os.getenv("DATA_DIR", data_dir)
        # the output file name
        self.FILE_NAME=os.getenv("FILE_NAME", "prodes_brasil")

    def __listFractionFiles(self, type):
        allFractionFiles = []
        for filename in glob.iglob(f"{self.DATA_DIR}/**/*.{type}", recursive=True):
            allFractionFiles.append(filename)
        return allFractionFiles

    def __loadEntriesFromFile(self, filename, type):
        
        with open(filename, 'r') as file:
            stringList = file.readlines()
            aFraction = f"""
                            <data>
                                {stringList}
                            </data>
                            """
            self.__mergeIntoMain(aFraction=aFraction, type=type)

    def __mergeIntoMain(self, aFraction, type):
        xmlFraction=xml_tag.fromstring(aFraction)
        for child in xmlFraction:
            if child.attrib['value'] not in self.mainFractions:
                
                paletteEntry=""
                if type=='sfl':
                    paletteEntry=f"""<{child.tag} color="{child.attrib['color']}" label="{child.attrib['label']}" value="{child.attrib['value']}" alpha="{child.attrib['alpha']}"/>"""
                else:
                    paletteEntry=f"""<{child.tag} color="{child.attrib['color']}" label="{child.attrib['label']}" quantity="{child.attrib['quantity']}"/>"""
                
                self.mainFractions[int(child.attrib['value'])]=paletteEntry


    def buildAndSaveFile(self):

        file_name=f"{self.FILE_NAME}"
        try:
            for type_file in self.types:
                self.mainFractions={}
                if os.path.isdir(self.DATA_DIR):
                    files=self.__listFractionFiles(type=type_file)
                    for f in files:
                        self.__loadEntriesFromFile(filename=f, type=type_file)
                    
                    path_dir=f"{self.DATA_DIR}"
                    mainFractions = dict(sorted(self.mainFractions.items()))

                    with open(os.path.join(path_dir, file_name), "w") as output_file:
                        for key in mainFractions:
                            output_file.write(f"{mainFractions[key]}\n")
        except Exception as e:
            print(f"Failure on store fragment.{e}")
        finally:
            print(f"Store fragment: {file_name}")


qml = BuildMosaicStyle()
qml.buildAndSaveFile()