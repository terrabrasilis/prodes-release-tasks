import glob
import os
from xml.etree import ElementTree as xml_tag

class BuildStyle:
    """
    Create main style entries for each style fraction.

    To merge into one QML fraction file and one SLD using all fractions from each table or each biome.

    The QML format is used for styling in QGIs.
    The SLD format is used for styling in GeoServer.
    """

    def __init__(self, output_file_name="prodes_brasil"):
        self.types=['sfl','sldf']
        # location of this file, used as default data dir
        data_dir=os.path.realpath(os.path.dirname(__file__) + '/files/')
        # the location to read the QML file fractions
        self.DATA_DIR=os.getenv("DATA_DIR", data_dir)
        # the output file name
        self.FILE_NAME=os.getenv("FILE_NAME", output_file_name)

    def __listFractionFiles(self, type):
        allFractionFiles = []
        for filename in glob.iglob(f"{self.DATA_DIR}/**/*.{type}", recursive=True):
            allFractionFiles.append(filename)
        return allFractionFiles

    def __loadEntriesFromFile(self, filename, type):
        
        with open(filename, 'r') as file:
            stringList = file.readlines()
            ns = "" if type=='sfl' else " xmlns:sld=\"sld\""
            aFraction = f"""
                        <data{ns}>
                            {stringList}
                        </data>
                        """
            self.__mergeIntoMain(aFraction=aFraction, type=type)

    def __mergeIntoMain(self, aFraction, type):
        xmlFraction=xml_tag.fromstring(aFraction)
        for child in xmlFraction:
            referency_value = child.attrib['value'] if type=='sfl' else child.attrib['quantity']
            if referency_value not in self.mainFractions:
                
                paletteEntry=""
                if type=='sfl':
                    paletteEntry=f"""<{child.tag} color="{child.attrib['color']}" label="{child.attrib['label']}" value="{child.attrib['value']}" alpha="{child.attrib['alpha']}"/>"""
                else:
                    paletteEntry=f"""<sld:ColorMapEntry color="{child.attrib['color']}" label="{child.attrib['label']}" quantity="{child.attrib['quantity']}"/>"""
                
                self.mainFractions[int(referency_value)]=paletteEntry


    def buildAndSaveFile(self):

        file_name=f"{self.FILE_NAME}"
        try:
            for type_file in self.types:
                self.mainFractions={}
                file_name=f"{self.FILE_NAME}.{type_file}"
                if os.path.isdir(self.DATA_DIR):
                    files=self.__listFractionFiles(type=type_file)
                    if len(files)>0:
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
            print(f"Fragment name: {file_name}")


qml = BuildStyle()
qml.buildAndSaveFile()