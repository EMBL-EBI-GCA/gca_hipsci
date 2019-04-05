
import json
import requests
import pickle
from datetime import datetime
import os.path
import sys
import csv
from os import listdir

# How to run the code:
# run the code with two arguments, your AAT username and password. Two lines running getCelllineDataHipSci and
# getCelllineDataBioSamples methods can be commented out after running them once as they build three files locally that
# will be used later on.

#  Production or Test version:
# The first argument needs to be either 'test' or 'production' and the relevant username password needs to be given.

code_mode = sys.argv[1]  # choose 'test' or 'production'
aai_username = sys.argv[2]
aai_password = sys.argv[3]


class HipSciVSBiosamples:
    """
    Gets the data associated with celllines and doners from HipSci API and BioSamples API in json format, then compares
    them and provides what is missing in the BioSamples and also what needs to be changed there.
    """

    response_dic = {}

    def __init__(self, dict_file, hipsci_file, biosample_file):
        """
        file three names (choose them) to be used to build the files.
        """
        self.dict_file = dict_file
        self.hipsci_file = hipsci_file
        self.biosample_file = biosample_file


    def getCelllinesSet(self):
        """
        Collects cellline ids from HipSci API.
        :return: a set of cellline ids.
        """

        response_num = requests.get("http://www.hipsci.org/lines/api/cellLine/_search?&pretty")
        HipSci_res = json.loads(response_num.text)
        celllines_num = HipSci_res['hits']['total']

        response_celllines = requests.get("http://www.hipsci.org/lines/api/cellLine/_search?size=" + str(celllines_num)
                                          + "&pretty") # legnth given so it collects all
        cellline_set = set()
        HipSci_celllines_res = json.loads(response_celllines.text)
        for result in HipSci_celllines_res['hits']['hits']:
            cellline_set.add(result['_id'].encode('utf-8'))
        return cellline_set  # len 3713 currently


    def getCelllineDataHipSci(self):
        """
        Gets a set of celllines, by calling getCelllinesSet method, and collects each cellline's data using HipSci API.
        :return: two dictionaries, both with cellline ids as their keys. cellline_data_dic has the data associated with
        each cellline id and cellline_biosample_dict has only the biosamples id. They both are saved in two files.
        """
        cellline_set = self.getCelllinesSet()
        cellline_data_dic = {}
        cellline_biosample_dict = {}

        for cellline in cellline_set:
            response_cellline = requests.get("http://www.hipsci.org/lines/api/cellLine/" + cellline)
            HipSci_celllines_res = json.loads(response_cellline.text)
            cellline_data_dic[cellline] = HipSci_celllines_res
            cellline_biosample_dict[cellline] = HipSci_celllines_res['_source']['bioSamplesAccession']

        dict_file_name = self.dict_file
        hipsci_file_name = self.hipsci_file
        self.pickleData(cellline_data_dic, hipsci_file_name)
        self.pickleData(cellline_biosample_dict, dict_file_name)

        return cellline_data_dic, cellline_biosample_dict


    def getCelllineDataBioSamples(self):
        """
        Collects the biosamples data from BioSamplaes data archive API.
        :return: a dictionary with biosample ids as keys and associated data as their values. It is saved in a file.
        """
        infile = open(self.dict_file, 'rb')
        celllines_biosamples = pickle.load(infile)
        infile.close()
        biosamples_data = {}

        for key, value in celllines_biosamples.items():
            response_bios = requests.get("http://www.ebi.ac.uk/biosamples/samples/" + value)
            bios_res = json.loads(response_bios.text)
            biosamples_data[value] = bios_res

        biosamples_file_name = self.biosample_file
        self.pickleData(biosamples_data, biosamples_file_name)

        return biosamples_data


    def pickleData(self, input_data, new_file_name):
        """
        This method gets an input data in any python format and saves it in a pickle format file.
        :param input_data: any python data structure.
        :param new_file_name: chosen name for the output file.
        :return: The file will be saved in the local directory, nothing will be returned.
        """
        outfile = open(new_file_name, 'wb')
        pickle.dump(input_data, outfile)
        outfile.close()


    def buildBioSamplesFormatDict(self):
        """
        Builds two new dictionaries, first one to use to collect, compare and prepare the data for submission. and one
        is in the exact format that BioSamples API requires.
        :return: Two dictionaries, biosamples_style_dict where all values are a list with single item of a dictionary.
        These dictionaries have one or two keys, they all have have 'value' as a key. Some have 'iri' also.
        individual_final_dict has two important fields for submitting data to BioSamples, attributesPre & attributesPost.
        """

        biosamples_style_dict = {}

        biosamples_style_dict['cell type'] = []
        biosamples_style_dict['cell type'].append(dict.fromkeys(['value', 'iri']))
        biosamples_style_dict['cell type'][0]['iri'] = []

        biosamples_style_dict['date of derivation'] = []
        biosamples_style_dict['date of derivation'].append(dict.fromkeys(['value']))

        biosamples_style_dict['age'] = []
        biosamples_style_dict['age'].append(dict.fromkeys(['value', 'unit']))

        biosamples_style_dict['Sex'] = []
        biosamples_style_dict['Sex'].append(dict.fromkeys(['value', 'iri']))
        biosamples_style_dict['Sex'][0]['iri'] = []

        biosamples_style_dict['donor id'] = []
        biosamples_style_dict['donor id'].append(dict.fromkeys(['value']))

        biosamples_style_dict['disease state'] = []
        biosamples_style_dict['disease state'].append(dict.fromkeys(['value', 'iri']))
        biosamples_style_dict['disease state'][0]['iri'] = []

        biosamples_style_dict['method of derivation'] = []
        biosamples_style_dict['method of derivation'].append(dict.fromkeys(['value']))

        biosamples_style_dict['ethnicity'] = []
        biosamples_style_dict['ethnicity'].append(dict.fromkeys(['value']))

        # non existing data in Biosamples
        biosamples_style_dict['reprogramming virus'] = []  # new
        biosamples_style_dict['reprogramming virus'].append(dict.fromkeys(['value']))

        biosamples_style_dict['reprogramming type'] = []  # new
        biosamples_style_dict['reprogramming type'].append(dict.fromkeys(['value']))

        biosamples_style_dict['culture summary'] = []
        biosamples_style_dict['culture summary'].append(dict.fromkeys(['value']))

        biosamples_style_dict['culture medium'] = []
        biosamples_style_dict['culture medium'].append(dict.fromkeys(['value']))

        biosamples_style_dict['culture CO2'] = []
        biosamples_style_dict['culture CO2'].append(dict.fromkeys(['value']))

        biosamples_style_dict['culture surface coating'] = []
        biosamples_style_dict['culture surface coating'].append(dict.fromkeys(['value']))

        biosamples_style_dict['culture passage method'] = []
        biosamples_style_dict['culture passage method'].append(dict.fromkeys(['value']))

        biosamples_style_dict['source material'] = []
        biosamples_style_dict['source material'].append(dict.fromkeys(['value', 'iri']))
        biosamples_style_dict['source material'][0]['iri'] = []

        biosamples_style_dict['source material cell type'] = []
        biosamples_style_dict['source material cell type'].append(dict.fromkeys(['value']))

        biosamples_style_dict['ebisc name'] = []
        biosamples_style_dict['ebisc name'].append(dict.fromkeys(['value']))

        biosamples_style_dict['eccac catalog number'] = []
        biosamples_style_dict['eccac catalog number'].append(dict.fromkeys(['value']))

        biosamples_style_dict['predicted population'] = []
        biosamples_style_dict['predicted population'].append(dict.fromkeys(['value']))

        biosamples_style_dict['open access'] = []
        biosamples_style_dict['open access'].append(dict.fromkeys(['value']))

        biosamples_style_dict['name'] = []
        biosamples_style_dict['name'].append(dict.fromkeys(['value']))

        biosamples_style_dict['tissue provider'] = []
        biosamples_style_dict['tissue provider'].append(dict.fromkeys(['value']))

        biosamples_style_dict['donor name'] = []
        biosamples_style_dict['donor name'].append(dict.fromkeys(['value']))

        biosamples_style_dict['hPSCreg name'] = []
        biosamples_style_dict['hPSCreg name'].append(dict.fromkeys(['value']))

        biosamples_style_dict['cnv length shared differences'] = []
        biosamples_style_dict['cnv length shared differences'].append(dict.fromkeys(['value']))

        biosamples_style_dict['cnv num different regions'] = []
        biosamples_style_dict['cnv num different regions'].append(dict.fromkeys(['value']))

        biosamples_style_dict['cnv length different regions mbp'] = []
        biosamples_style_dict['cnv length different regions mbp'].append(dict.fromkeys(['value']))

        biosamples_style_dict['banking status'] = []
        biosamples_style_dict['banking status'].append(dict.fromkeys(['value']))  # this will be a list

        # final biosamples API dictionary for individual samples
        individual_final_dict = dict.fromkeys(["sample", "curation", "domain"]) # "created", "hash"
        individual_final_dict["curation"] = dict.fromkeys(["attributesPre", "attributesPost", "externalReferencesPre",
                                                    "externalReferencesPost"])  # "hash"
        individual_final_dict["curation"]["attributesPre"] = [] # the one that needs to be changed
        individual_final_dict["curation"]["attributesPost"] = [] # another one that needs to be changed
        individual_final_dict["curation"]["externalReferencesPre"] = []
        individual_final_dict["curation"]["externalReferencesPost"] = []

        return biosamples_style_dict, individual_final_dict


    def addNonExistingData(self, hipsci_data_file, bs_style_dict):
        """
        Gets an empty dictionary in a exact format built by buildBioSamplesFormatDict method and populates it with the
        keys and their associated values that exist only on HipSci.
        :param hipsci_data_file: the pickled file containing all data collected from HipSci API.
        :param bs_style_dict: an empty dictioanry built by buildBioSamplesFormatDict.
        :return: a dictionary with data that is not available in BioSamples data archive, data collected from HipSci.
        """
        bs_style_dict['ebisc name'][0]['value'] = hipsci_data_file['_source'].get('ebiscName')
        bs_style_dict['eccac catalog number'][0]['value'] = hipsci_data_file['_source'].get('eccacCatalogNumber')
        bs_style_dict['predicted population'][0]['value'] = hipsci_data_file['_source'].get('predictedPopulation')
        bs_style_dict['open access'][0]['value'] = hipsci_data_file['_source'].get('openAccess')
        bs_style_dict['name'][0]['value'] = hipsci_data_file['_source'].get('name')
        bs_style_dict['tissue provider'][0]['value'] = hipsci_data_file['_source'].get('tissueProvider')
        bs_style_dict['donor name'][0]['value'] = hipsci_data_file['_source']['donor'].get('name') # donor is in all
        bs_style_dict['hPSCreg name'][0]['value'] = hipsci_data_file['_source'].get('hPSCregName')

        source_material_data = hipsci_data_file['_source'].get('sourceMaterial')
        if source_material_data:
            bs_style_dict['source material'][0]['value'] = source_material_data.get('value')
            bs_style_dict['source material'][0]['iri'].append(source_material_data.get('ontologyPURL'))
            bs_style_dict['source material cell type'][0]['value'] = source_material_data.get('cellType')

        culture_data = hipsci_data_file['_source'].get('culture')
        if culture_data:
            bs_style_dict['culture summary'][0]['value'] = culture_data.get('summary')
            bs_style_dict['culture medium'][0]['value'] = culture_data.get('medium')
            bs_style_dict['culture CO2'][0]['value'] = culture_data.get('CO2')
            bs_style_dict['culture surface coating'][0]['value'] = culture_data.get('surfaceCoating')
            bs_style_dict['culture passage method'][0]['value'] = culture_data.get('passageMethod')

        reprogramming_data = hipsci_data_file['_source'].get('reprogramming')
        if reprogramming_data:
            bs_style_dict['reprogramming virus'][0]['value'] = reprogramming_data.get('virus')
            bs_style_dict['reprogramming type'][0]['value'] = reprogramming_data.get('type')

        cnv_data_dict = hipsci_data_file['_source'].get('cnv')
        if cnv_data_dict:
            bs_style_dict['cnv length shared differences'][0]['value'] = cnv_data_dict.get('length_shared_differences')
            bs_style_dict['cnv num different regions'][0]['value'] = cnv_data_dict.get('num_different_regions')
            bs_style_dict['cnv length different regions mbp'][0]['value'] = cnv_data_dict.get('length_different_regions_Mbp')

        if hipsci_data_file['_source'].get('bankingStatus'): # this was a list
            banking_status_list = [status.encode("utf-8") for status in hipsci_data_file['_source'].get('bankingStatus')]
            banking_status_string = banking_status_list[0]
            for status in banking_status_list[1:]:
                banking_status_string =  banking_status_string + ', ' + status
            bs_style_dict['banking status'][0]['value'] = banking_status_string

        return bs_style_dict


    def compareAndCompleteDict(self):
        """
        Get's the three pickled files that were built by the previous methods so it can compare the common data available
        in both HipSci file and BioSamples file. It then goes through the celllines and builds an empty dictionary using
        buildBioSamplesFormatDict method and populates it with the data from HipSci by addNonExistingData method. Then
        compares the common values of missing parts and change them to what is received from HipSci if they are different.
        It will then removes the missing values.
        :return: a large dictionary containing all celllines with new data to be added, the keys are sample accessions
        and the values are the dictionaries. It also returns a dictionary with accession as keys and a list as their
        values. each list item is a tuple of what has been changed. with key and its key if there is one. Ex:
        {'SAMEA4088905': [('disease state', 'ontologyTerms'), ('cell type', 'text')], 'SAMEA2796331': .....}
        """

        EXCL_CELLTYPE = 'iPSC' # disregarded, an exception, it's "induced pluripotent stem cell" in BioSamples

        infile = open(self.hipsci_file, 'rb')
        HS_data = pickle.load(infile)  # HPSI1014i-suok_5, data
        infile.close()

        infile = open(self.biosample_file, 'rb')
        BS_data = pickle.load(infile) # SAMEA2658090, data
        infile.close()

        infile = open(self.dict_file, 'rb')
        HS_BS_dict = pickle.load(infile) # # HPSI0514i-yewo_3, SAMEA103884171
        infile.close()

        empty_dict = self.buildBioSamplesFormatDict()[0]

        final_dictionary = {}
        difference_dic = {} # can be removed entirely, only for testing
        pre_change_dict = {}

        for key, value in HS_BS_dict.items(): # HPSI0514i-yewo_3, SAMEA103884171
            initial_dict = self.buildBioSamplesFormatDict()[0]
            final_dictionary[value] = self.addNonExistingData(HS_data[key], initial_dict)
            pre_change_dict[value] = self.buildBioSamplesFormatDict()[0]
            difference_dic[value] = []

            HS_disease_info = HS_data[key]['_source'].get('diseaseStatus')
            BS_disease_info = BS_data[value]['characteristics'].get('disease state')
            if HS_disease_info:
                if BS_disease_info:
                    if HS_disease_info['ontologyPURL'].lower() != BS_disease_info[0]['ontologyTerms'][0].lower():
                        final_dictionary[value]['disease state'][0]['iri'].append(HS_disease_info['ontologyPURL'])
                        pre_change_dict[value]['disease state'][0]['iri'] = BS_disease_info[0]['ontologyTerms']
                        final_dictionary[value]['disease state'][0]['value'] = BS_disease_info[0]['text']
                        pre_change_dict[value]['disease state'][0]['value'] = BS_disease_info[0]['text']
                        difference_dic[value].append(('disease state', 'iri'))
                    if HS_disease_info['value'].lower() != BS_disease_info[0]['text'].lower():
                        final_dictionary[value]['disease state'][0]['value'] = HS_disease_info['value']
                        pre_change_dict[value]['disease state'][0]['value'] = BS_disease_info[0]['text']
                        if final_dictionary[value]['disease state'][0]['iri'] == []:
                            final_dictionary[value]['disease state'][0]['iri'] = BS_disease_info[0]['ontologyTerms']
                            pre_change_dict[value]['disease state'][0]['iri'] = BS_disease_info[0]['ontologyTerms']
                        difference_dic[value].append(('disease state', 'value'))
                else:
                    final_dictionary[value]['disease state'][0]['iri'].append(HS_disease_info['ontologyPURL'])
                    final_dictionary[value]['disease state'][0]['value'] = HS_disease_info['value']

            HS_derivation_info = HS_data[key]['_source'].get('reprogramming')
            BS_derivation_date_info = BS_data[value]['characteristics'].get('date of derivation')
            BS_derivation_method_info = BS_data[value]['characteristics'].get('method of derivation')
            if HS_derivation_info and HS_derivation_info.get('dateOfDerivation'):
                if BS_derivation_date_info and BS_derivation_date_info[0].get('text'):
                    if HS_derivation_info['dateOfDerivation'].lower() != BS_derivation_date_info[0]['text'].lower():
                        final_dictionary[value]['date of derivation'][0]['value'] = HS_derivation_info['dateOfDerivation']
                        pre_change_dict[value]['date of derivation'][0]['value'] = BS_derivation_date_info[0]['text']
                        difference_dic[value].append(('date of derivation', 'value'))
                else:
                    final_dictionary[value]['date of derivation'][0]['value'] = HS_derivation_info['dateOfDerivation']
            if HS_derivation_info and HS_derivation_info.get('methodOfDerivation'):
                if BS_derivation_method_info and BS_derivation_method_info[0].get('text'):
                    if HS_derivation_info['methodOfDerivation'].lower() != BS_derivation_method_info[0]['text'].lower():
                        final_dictionary[value]['method of derivation'][0]['value'] = HS_derivation_info['methodOfDerivation']
                        pre_change_dict[value]['method of derivation'][0]['value'] = BS_derivation_method_info[0]['text']
                        difference_dic[value].append(('method of derivation', 'value'))
                else:
                    final_dictionary[value]['method of derivation'][0]['value'] = HS_derivation_info['methodOfDerivation']

            HS_celltype_info = HS_data[key]['_source'].get('cellType')
            BS_celltype_info = BS_data[value]['characteristics'].get('cell type')
            if HS_celltype_info:
                if BS_celltype_info:
                    if HS_celltype_info['ontologyPURL'].lower() != BS_celltype_info[0]['ontologyTerms'][0].lower():
                        final_dictionary[value]['cell type'][0]['iri'].append(HS_celltype_info['ontologyPURL'])
                        pre_change_dict[value]['cell type'][0]['iri'] = BS_celltype_info[0]['ontologyTerms']
                        final_dictionary[value]['cell type'][0]['value'] = BS_celltype_info[0]['text']
                        pre_change_dict[value]['cell type'][0]['value'] = BS_celltype_info[0]['text']
                        difference_dic[value].append(('cell type', 'iri'))
                    if HS_celltype_info['value'].lower() != BS_celltype_info[0]['text'].lower() and \
                            HS_celltype_info['value'] != EXCL_CELLTYPE:
                        final_dictionary[value]['cell type'][0]['value'] = HS_celltype_info['value']
                        pre_change_dict[value]['cell type'][0]['value'] = BS_celltype_info[0]['text']
                        if final_dictionary[value]['cell type'][0]['iri'] == []:
                            final_dictionary[value]['cell type'][0]['iri'] = BS_celltype_info[0]['ontologyTerms']
                            pre_change_dict[value]['cell type'][0]['iri'] = BS_celltype_info[0]['ontologyTerms']
                        difference_dic[value].append(('cell type', 'value'))
                else:
                    final_dictionary[value]['cell type'][0]['value'] = HS_celltype_info['value']
                    final_dictionary[value]['cell type'][0]['iri'].append(HS_celltype_info['ontologyPURL'])

            HS_donor_info = HS_data[key]['_source'].get('donor')
            BS_age_info = BS_data[value]['characteristics'].get('age')
            BS_sex_info = BS_data[value]['characteristics'].get('Sex')
            BS_ethnicity_info = BS_data[value]['characteristics'].get('ethnicity')
            BS_donor_acc_info = BS_data[value]['characteristics'].get('donor id')
            if HS_donor_info:
                if HS_donor_info.get('age'):
                    if BS_age_info:
                        if HS_donor_info['age'].lower() != BS_age_info[0]['text'].lower():
                            final_dictionary[value]['age'][0]['value'] = HS_donor_info['age']
                            pre_change_dict[value]['age'][0]['value'] = BS_age_info[0]['text']
                            final_dictionary[value]['age'][0]['unit'] = 'year'
                            pre_change_dict[value]['age'][0]['unit'] = 'year'
                            difference_dic[value].append(('age', 'value'))
                    else:
                        final_dictionary[value]['age'][0]['value'] = HS_donor_info['age']
                        final_dictionary[value]['age'][0]['unit'] = 'year'

                if HS_donor_info.get('ethnicity'):
                    if BS_ethnicity_info and BS_ethnicity_info[0].get('text'):
                        if HS_donor_info['ethnicity'].lower() != BS_ethnicity_info[0]['text'].lower():
                            final_dictionary[value]['ethnicity'][0]['value'] = HS_donor_info['ethnicity']
                            pre_change_dict[value]['ethnicity'][0]['value'] = BS_ethnicity_info[0]['text']
                            difference_dic[value].append(('ethnicity', 'value'))
                    else:
                        final_dictionary[value]['ethnicity'][0]['value'] = HS_donor_info['ethnicity']

                if HS_donor_info.get('bioSamplesAccession'):
                    if BS_donor_acc_info and BS_donor_acc_info[0].get('text'):
                        if HS_donor_info['bioSamplesAccession'].lower() != BS_donor_acc_info[0]['text'].lower():
                            final_dictionary[value]['donor id'][0]['value'] = HS_donor_info['bioSamplesAccession']
                            pre_change_dict[value]['donor id'][0]['value'] = BS_donor_acc_info[0]['text']
                            difference_dic[value].append(('donor id', 'value'))
                    else:
                        final_dictionary[value]['donor id'][0]['value'] = HS_donor_info['bioSamplesAccession']

                if HS_donor_info.get('sex'):
                    if BS_sex_info:
                        if HS_donor_info['sex']['ontologyPURL'].lower() != BS_sex_info[0]['ontologyTerms'][0].lower():
                            final_dictionary[value]['Sex'][0]['iri'].append(HS_donor_info['sex']['ontologyPURL'])
                            pre_change_dict[value]['Sex'][0]['iri'] = BS_sex_info[0]['ontologyTerms']
                            final_dictionary[value]['Sex'][0]['value'] = BS_sex_info[0]['text']
                            pre_change_dict[value]['Sex'][0]['value'] = BS_sex_info[0]['text']
                            difference_dic[value].append(('sex', 'iri'))
                        if HS_donor_info['sex']['value'].lower() != BS_sex_info[0]['text'].lower():
                            final_dictionary[value]['Sex'][0]['value'] = HS_donor_info['sex']['value']
                            pre_change_dict[value]['Sex'][0]['value'] = BS_sex_info[0]['text']
                            if final_dictionary[value]['Sex'][0]['iri'] == []:
                                final_dictionary[value]['Sex'][0]['iri'] = BS_sex_info[0]['ontologyTerms']
                                final_dictionary[value]['Sex'][0]['iri'] = BS_sex_info[0]['ontologyTerms']
                            difference_dic[value].append(('sex', 'value'))
                    else:
                        final_dictionary[value]['Sex'][0]['value'] = HS_donor_info['sex']['value']
                        final_dictionary[value]['Sex'][0]['iri'].append(HS_donor_info['sex']['ontologyPURL'])

            if difference_dic[value] == []: # removes the ones that have no new data.
                del difference_dic[value]

            for key in empty_dict.keys(): # to remove null or [] values
                if final_dictionary[value][key][0] == empty_dict[key][0]:
                    del final_dictionary[value][key]
                if pre_change_dict[value][key][0] == empty_dict[key][0]:
                    del pre_change_dict[value][key]

        return pre_change_dict, final_dictionary


    def generateIndividualFinalJSONFiles(self): # a generator
        """
        This is a generator to build each individual json data for each particular cellline and each new/changed attribute.
        :return: yields each dictionary one by one so they can be uploaded individually.
        """
        biosamples_pre_dict, biosamples_post_dict = self.compareAndCompleteDict()
        i = 0
        for key, value in biosamples_post_dict.items():
            for dict_key in value.keys():
                final_dict = self.buildBioSamplesFormatDict()[1]
                final_dict["sample"] = key
                final_dict["domain"] = "self.HipSci_DCC_curation"
                final_dict["curation"]["attributesPost"].append({'type': dict_key})
                final_dict["curation"]["attributesPost"][0].update(value[dict_key][0])
                if key in biosamples_pre_dict.keys() and dict_key in biosamples_pre_dict[key].keys():
                    final_dict["curation"]["attributesPre"].append({'type': dict_key})
                    final_dict["curation"]["attributesPre"][0].update(biosamples_pre_dict[key][dict_key][0])
                print i
                i += 1
                yield final_dict


    def getAAIToken(self, mode, username, password):
        """
        Gets a token from AAI to be used for submitting data.
        :param username: first argument when running the code
        :param password: second argument when running the code
        :return: returns a token to be used for posting data to BioSamples archive.
        """
        if mode == 'test':
            url = "https://explore.api.aai.ebi.ac.uk/auth"  # for development / test version
        elif mode == 'production':
            url = "https://api.aai.ebi.ac.uk/auth"  # for production version
        else:
            print "choose between 'test' or 'production' version and enter appropriate username and password"

        response = requests.get(url, auth=(username, password))

        return (response.text).encode("utf-8")


    def postDataToBioSamples(self, mode, data_dict, aai_token):
        """
        Post the data generated by generateIndividualFinalJSONFiles method to BioSamples archive using the token.
        :param data_dict: generated one by one by generateIndividualFinalJSONFiles.
        :param aai_token: AAI token for Biosamples athentication.
        :return: Doesn't return anything, it does write the response in a txt file ('response.txt'). It also populates
        the class variable, response_dic, so it can be written into a json file in a standard way. It also write the
        accession number and the field that has been changed in a csv file called 'acc_and_type.csv'.
        """
        if mode == 'test':
            url = "https://wwwdev.ebi.ac.uk/biosamples/samples/" + data_dict['sample'] + "/curationlinks"  # for development / test version
        elif mode == 'production':
            url = "https://www.ebi.ac.uk/biosamples/samples/" + data_dict['sample'] + "/curationlinks" # for production version
        else:
            print "choose between 'test' or 'production' version and enter appropriate username and password"

        final_json = json.dumps(data_dict, ensure_ascii=False)
        payload = final_json
        headers = {
            'Content-Type': "application/json",
            'Accept': "application/hal+json",
            'Authorization': "Bearer " + aai_token,
            'cache-control': "no-cache"
        }
        response = requests.request("POST", url, data=payload, headers=headers)
        # print data_dict['sample'], data_dict['curation']['attributesPost'][0]['type']

        try:
            rep_dict = json.loads(response.text)
        except:
            rep_dict = {data_dict["sample"]: data_dict["curation"]['attributesPost'][0]['type'], "error": "json load"}

        text_file = open('response.txt', 'a+')
        text_file.write(response.text + '\n')
        text_file.close()
        row = [data_dict['sample'], data_dict['curation']['attributesPost'][0]['type']]
        with open('acc_and_type.csv', 'a') as csvFile:
            writer = csv.writer(csvFile)
            writer.writerow(row)
        if data_dict['sample'] in self.response_dic.keys():
            self.response_dic[data_dict['sample']].update({data_dict['curation']['attributesPost'][0]['type']: rep_dict})
        else:
            self.response_dic[data_dict['sample']] = {data_dict['curation']['attributesPost'][0]['type']: rep_dict}


# new_instance = HipSciVSBiosamples('TEST_HS_BS_dict', 'hipsci_data', 'biosamples_data') # this is a test versions
new_instance = HipSciVSBiosamples('HS_BS_dict', 'hipsci_data', 'biosamples_data')
new_instance.getCelllineDataHipSci()  # comment out after first time
new_instance.getCelllineDataBioSamples()  # Authorization comment out after first time

# comment out first to get the data then uncomment
gen = new_instance.generateIndividualFinalJSONFiles()
VALID_TIME = 55 * 60 # 55 minutes in seconds
initial_time = datetime.now()
token = new_instance.getAAIToken(code_mode, aai_username, aai_password)
for post_dict in gen:
    interval = datetime.now() - initial_time
    if interval.seconds < VALID_TIME:
        new_instance.postDataToBioSamples(code_mode, post_dict, token)
    else:
        initial_time = datetime.now()
        token = new_instance.getAAIToken(code_mode, aai_username, aai_password)
        new_instance.postDataToBioSamples(code_mode, post_dict, token)

with open('response.json', 'a') as jf:
    json.dump(new_instance.response_dic, jf, indent=4)
# ######


# More information
# IMPORTANT: run HipSciVSBiosamples('TETS_HS_BS_dict', 'hipsci_data', 'biosamples_data') for testing.
# then change that to HipSciVSBiosamples('HS_BS_dict', 'hipsci_data', 'biosamples_data') for production.
# define instance of this class with three chosen file names, then run getCelllineDataHipSci method to build two pickled
# files (hipsci data and dictionary of cellline ids and biosamples accessions). Then run getCelllineDataBioSamples to
# collect BioSamples data and build a pickled file. These methods can be commented out if we want to run the code again.
# The data is collected and saved locally.
# Then run generateIndividualFinalJSONFiles to build a generate to get individual json format data for updating biosamples.
# The last two methods and final lines of the code get's an AAT token, and updates the Biosamples archive until 55min has
# past, when it generates a new token and carrys on with the same process.
# Builds two files, ome text and one json from the response it receives from BioSamples API. 'response.txt', 'response.json'
# {"SAMEA4453758": {"index": {response}, "banking status": {response} ... . . . }, "SAMEA65333422": { ..... .... }}


# for testing purposes:
# test_list = [u'SAMEA3355536', u'SAMEA3355535', u'SAMEA4451167', u'SAMEA4451168', u'SAMEA4451169', u'SAMEA4451171',
#              u'SAMEA3355538', u'SAMEA3355539', u'SAMEA104619372', u'SAMEA104619373', u'SAMEA4453887', u'SAMEA4453886',
#              u'SAMEA2398333', u'SAMEA4453758', u'SAMEA2398656', u'SAMEA4453865', u'SAMEA4453761', u'SAMEA17596918',
#              u'SAMEA104132160', u'SAMEA3355541']

# some accessions that return different common values:
# 'SAMEA104134262', 'SAMEA103884566', 'SAMEA103884569', 'SAMEA4448524', 'SAMEA104132156', 'SAMEA103887524',
# 'SAMEA104132052', 'SAMEA4453884', 'SAMEA104012318', 'SAMEA104134252', 'SAMEA104236993', 'SAMEA104132428'

# some accessions with maximum number of keys in both HipSci and BioSamples dictionaries:
# u'SAMEA2698314', u'SAMEA3355549', u'SAMEA2612483', u'SAMEA2536412']
