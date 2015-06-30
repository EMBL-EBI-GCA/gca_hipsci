CREATE TABLE cell_line(
       cell_line_id int unsigned NOT NULL AUTO_INCREMENT,
       name char(18) NOT NULL,
       short_name char(7) NOT NULL,
       donor char(9),
       biosample_id char(12),
       donor_biosample_id char(12),
       cell_type varchar(255),
       is_on_feeder tinyint,
       gender varchar(255),
       age varchar(255),
       disease varchar(255),
       ethnicity varchar(255),
       derived_from_tissue_type varchar(255),
       reprogramming varchar(255),
       PRIMARY KEY (cell_line_id),
       UNIQUE INDEX (name),
       UNIQUE INDEX (short_name)
) ENGINE=InnoDB;

CREATE TABLE experiment(
       experiment_id int unsigned NOT NULL AUTO_INCREMENT,
       cell_line_id int unsigned NOT NULL,
       evaluation_guid char(36) NOT NULL,
       experiment_name varchar(255) NOT NULL,
       p_col tinyint unsigned NOT NULL,
       p_row tinyint unsigned NOT NULL,
       is_production boolean NOT NULL,
       num_cells smallint unsigned NOT NULL,
       nuc_area_mean double,
       nuc_area_sd double,
       nuc_area_sum double,
       nuc_area_max double,
       nuc_area_min double,
       nuc_area_median double,
       nuc_roundness_mean double,
       nuc_roundness_sd double,
       nuc_roundness_sum double,
       nuc_roundness_max double,
       nuc_roundness_min double,
       nuc_roundness_median double,
       nuc_ratio_w2l_mean double,
       nuc_ratio_w2l_sd double,
       nuc_ratio_w2l_sum double,
       nuc_ratio_w2l_max double,
       nuc_ratio_w2l_min double,
       nuc_ratio_w2l_median double,
       edu_median_mean double,
       edu_median_sd double,
       edu_median_sum int,
       edu_median_max mediumint,
       edu_median_min mediumint,
       edu_median_median mediumint,
       oct4_median_mean double,
       oct4_median_sd double,
       oct4_median_sum int,
       oct4_median_max mediumint,
       oct4_median_min mediumint,
       oct4_median_median mediumint,
       inten_nuc_dapi_median_mean double,
       inten_nuc_dapi_median_sd double,
       inten_nuc_dapi_median_sum int,
       inten_nuc_dapi_median_max mediumint,
       inten_nuc_dapi_median_min mediumint,
       inten_nuc_dapi_median_median mediumint,
       cells_per_clump_mean double,
       cells_per_clump_sd double,
       cells_per_clump_sum smallint,
       cells_per_clump_max smallint,
       cells_per_clump_min smallint,
       cells_per_clump_median smallint,
       area_mean double,
       area_sd double,
       area_sum double,
       area_max double,
       area_min double,
       area_median double,
       roundness_mean double,
       roundness_sd double,
       roundness_sum double,
       roundness_max double,
       roundness_min double,
       roundness_median double,
       ratio_w2l_mean double,
       ratio_w2l_sd double,
       ratio_w2l_sum double,
       ratio_w2l_max double,
       ratio_w2l_min double,
       ratio_w2l_median double,
       compound varchar(255),
       concentration double,
       cell_count smallint,
       num_fields tinyint NOT NULL,
       PRIMARY KEY (experiment_id),
       UNIQUE INDEX (p_col, p_row, evaluation_guid),
       FOREIGN KEY fk_experiment_line_line_id (cell_line_id) REFERENCES cell_line(cell_line_id)
) ENGINE=InnoDB;

CREATE TABLE cell(
       cell_id int unsigned NOT NULL AUTO_INCREMENT,
       experiment_id int unsigned NOT NULL,
       field tinyint unsigned NOT NULL,
       i_cell smallint NOT NULL,
       i_cell_unselected smallint NOT NULL,
       i_clump_singles smallint NOT NULL,
       i_nuc smallint NOT NULL,
       i_nuc2 smallint NOT NULL,
       x_centroid smallint unsigned NOT NULL,
       x_min smallint unsigned NOT NULL,
       x_max smallint unsigned NOT NULL,
       y_centroid smallint unsigned NOT NULL,
       y_min smallint unsigned NOT NULL,
       y_max smallint unsigned NOT NULL,
       cell_area float unsigned NOT NULL,
       edu_median mediumint unsigned NOT NULL,
       oct4_median mediumint unsigned NOT NULL,
       inten_nuc_dapi_median mediumint unsigned NOT NULL,
       roundness float NOT NULL,
       ratio_w2l float NOT NULL,
       nucleus_area float unsigned NOT NULL,
       nucleus_roundness float unsigned NOT NULL,
       nucleus_ratio_w2l float unsigned NOT NULL,
       clump_size smallint NOT NULL,
       PRIMARY KEY (cell_id),
       FOREIGN KEY fk_cell_experiment_experiment_id (experiment_id) REFERENCES experiment(experiment_id)
) ENGINE=InnoDB;
